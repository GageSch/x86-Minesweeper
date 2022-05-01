%include "/usr/local/share/csc314/asm_io.inc"

; the file that stores the initial state
%define BOARD_FILE 'board.txt'

; how to represent everything
%define WALL_CHAR '#'
%define PLAYER_CHAR '~'
%define MINECHAR '*'
%define FLAGGED '?'
%define COVEREDCHAR 'X'
%define EMPTYCHAR ' '

; the size of the game screen in characters
%define HEIGHT 20
%define WIDTH 40

%define SQUARES (19*39)

; the player starting position.
; top left is considered (0,0)
%define STARTX 1
%define STARTY 1

; these keys do things
%define EXITCHAR 'x'
%define UPCHAR 'w'
%define LEFTCHAR 'a'
%define DOWNCHAR 's'
%define RIGHTCHAR 'd'
%define FLAGCHAR 'f'
%define DIGCHAR 'e'

%define NUMBER_MINES 40

segment .data

        ; used to fopen the board file defined above
        board_file                      db BOARD_FILE,0
        ; used to chane the terminal mode
        mode_r                          db "r",0
        raw_mode_on_cmd         db "stty raw -echo",0
        raw_mode_off_cmd        db "stty -raw echo",0

        ; ANSI escape sequence to clear/refresh the screen
        clear_screen_code       db      27,"[2J",27,"[H",0

        ; things the program will print
        help_str                        db 13,10,"Controls: ", \
                                                        UPCHAR,"=UP | ", \
                                                        LEFTCHAR,"=LEFT | ", \
                                                        DOWNCHAR,"=DOWN | ", \
                                                        RIGHTCHAR,"=RIGHT | ", \
                                                        FLAGCHAR,"=FLAG | ", \
                                                        DIGCHAR,"=DIG | ", \
                                                        EXITCHAR,"=END GAME", \
                                                        13,10,10,0

        start_str                       db      "___  ________ _   _  _____ _____  _    _ _____ ___________ ___________ ", 13, 10, \
                                                        "|  \/  |_   _| \ | ||  ___/  ___|| |  | |  ___|  ___| ___ \  ___| ___ \", 13, 10, \
                                                        "| .  . | | | |  \| || |__ \ `--. | |  | | |__ | |__ | |_/ / |__ | |_/ /", 13, 10, \
                                                        "| |\/| | | | | . ` ||  __| `--. \| |/\| |  __||  __||  __/|  __||    / ", 13, 10, \
                                                        "| |  | |_| |_| |\  || |___/\__/ /\  /\  / |___| |___| |   | |___| |\ \ ", 13, 10, \
                                                        "\_|  |_/\___/\_| \_/\____/\____/  \/  \/\____/\____/\_|   \____/\_| \_|", 13, 10, 10, \
                                                        "Press any key to start", 13, 10, 10, 10, 0

        loss_str                        db      13, 10, "You Lost", 13, 10, 10, \
                                                                        "Press any key to continue", 13, 10, 0

        win_str                         db      13, 10, "You Won!", 13, 10, 10, \
                                                                        "Press any key to continue", 13, 10, 0

        menu_str                        db      "Select your option:", 13, 10, \
                                                        "1) Play again", 13, 10, \
                                                        "0) Quit", 13, 10, 0

        redo_str                        db      13, 10, "Please select a valid option", 13, 10, 0

        cursor_str                      db      `\e[1;7m%c\e[0m`, 0

        covered_str                     db      `\e[37;47m%c\e[0m`, 0

        empty_str                       db      `\e[90;100m%c\e[0m`, 0

        one_str                         db      `\e[34;100m%c\e[0m`, 0
        two_str                         db      `\e[32;100m%c\e[0m`, 0
        three_str                       db      `\e[31;100m%c\e[0m`, 0
        four_str                        db      `\e[91;100m%c\e[0m`, 0
        five_str                        db      `\e[36;100m%c\e[0m`, 0
        six_str                         db      `\e[92;100m%c\e[0m`, 0
        seven_str                       db      `\e[96;100m%c\e[0m`, 0
        eight_str                       db      `\e[95;100m%c\e[0m`, 0

        mine_str                        db      `\e[30;41m%c\e[0m`, 0

        flag_str                        db      `\e[31;47m%c\e[0m`, 0

segment .bss

        ; this array stores the current rendered gameboard (HxW)
        board   resb    (HEIGHT * WIDTH)
        mboard  resb    (HEIGHT * WIDTH)
        ; these variables store the current player position
        xpos    resd    1
        ypos    resd    1

segment .text

        global  asm_main
        global  raw_mode_on
        global  raw_mode_off
        global  init_board
        global  render

        extern  system
        extern  putchar
        extern  getchar
        extern  printf
        extern  fopen
        extern  fread
        extern  fgetc
        extern  fclose
        extern  srand
        extern  rand
        extern  time

asm_main:
        push    ebp
        mov             ebp, esp

        ;srand(time(null))
        push    0
        call    time
        add             esp, 4

        push    eax
        call    srand
        add             esp, 4

        ; put the terminal in raw mode so the game works nicely
        call    raw_mode_on

        push    clear_screen_code
        call    printf
        add             esp, 4

        push    start_str
        call    printf
        add             esp, 4

        call    getchar

        gui_loop:

        ; read the game board file into the global variable
        call    init_board

        call    clear_mines

        call    get_mines

        call    get_nums

        ; set the player at the proper start position
        mov             DWORD [xpos], STARTX
        mov             DWORD [ypos], STARTY

        ; the game happens in this loop
        ; the steps are...
        ;   1. render (draw) the current board
        ;   2. get a character from the user
        ;       3. store current xpos,ypos in esi,edi
        ;       4. update xpos,ypos based on character from user
        ;       5. check what's in the buffer (board) at new xpos,ypos
        ;       6. if it's a wall, reset xpos,ypos to saved esi,edi
        ;       7. otherwise, just continue! (xpos,ypos are ok)
        game_loop:

                ; draw the game board
                call    render

                ;if gameiswon()
                ;end game
                call    game_is_won
                cmp             eax, 1
                jne             continuegame

                        mov             DWORD [xpos], -1
                        mov             DWORD [ypos], -1
                        call    render
                        push    win_str
                        jmp             game_loop_end

                continuegame:


                ; get an action from the user
                call    getchar

                ; store the current position
                ; we will test if the new position is legal
                ; if not, we will restore these
                mov             esi, DWORD [xpos]
                mov             edi, DWORD [ypos]

                ; choose what to do
                cmp             eax, EXITCHAR
                je              exitwithchar
                cmp             eax, UPCHAR
                je              move_up
                cmp             eax, LEFTCHAR
                je              move_left
                cmp             eax, DOWNCHAR
                je              move_down
                cmp             eax, RIGHTCHAR
                je              move_right
                cmp             eax, FLAGCHAR
                je              flag
                cmp             eax, DIGCHAR
                je              dig
                jmp             input_end                       ; or just do nothing

                ; move the player according to the input character
                move_up:
                        dec             DWORD [ypos]
                        jmp             input_end
                move_left:
                        dec             DWORD [xpos]
                        jmp             input_end
                move_down:
                        inc             DWORD [ypos]
                        jmp             input_end
                move_right:
                        inc             DWORD [xpos]
                        jmp             input_end
                flag:
                        mov             eax, WIDTH
                        mul             DWORD [ypos]
                        add             eax, DWORD [xpos]
                        lea             eax, [board + eax]
                        cmp             BYTE [eax], FLAGGED
                        je              removeflag
                        cmp             BYTE [eax], COVEREDCHAR
                        jne             input_end
                                mov             BYTE [eax], FLAGGED
                                jmp             input_end
                        removeflag:
                                mov             BYTE [eax], COVEREDCHAR
                                jmp             input_end
                dig:
                        mov             eax, WIDTH
                        mul             DWORD [ypos]
                        add             eax, DWORD [xpos]
                        lea             ebx, [board + eax]
                        cmp             BYTE [ebx], COVEREDCHAR
                        jne             input_end
                                lea             eax, [mboard + eax]
                                mov             al, BYTE [eax]
                                mov             BYTE [ebx], al
                                cmp             al, MINECHAR
                                je              ifmine
                                cmp             al, EMPTYCHAR
                                jne             input_end

                                        yescas:
                                        call    cascade
                                        jmp             input_end

                                        ifmine:
                                        mov             DWORD [xpos], -1
                                        mov             DWORD [ypos], -1
                                        call    render
                                        push    loss_str
                                        jmp             game_loop_end

                input_end:

                ; (W * y) + x = pos

                ; compare the current position to the wall character
                mov             eax, WIDTH
                mul             DWORD [ypos]
                add             eax, DWORD [xpos]
                lea             eax, [board + eax]
                cmp             BYTE [eax], WALL_CHAR
                jne             valid_move
                        ; opps, that was an invalid move, reset
                        mov             DWORD [xpos], esi
                        mov             DWORD [ypos], edi
                valid_move:

        jmp             game_loop
        game_loop_end:


        call    printf
        add             esp, 4

        call    getchar

        exitwithchar:

        push    clear_screen_code
        call    printf
        add             esp, 4

        push    menu_str
        call    printf
        add             esp, 4

        topmenuloop:
        call    getchar
        cmp             eax, '1'
        je              option1
        cmp             eax, '0'
        je              option0

                push    redo_str
                call    printf
                add             esp, 4
                jmp             topmenuloop

        option1:
                jmp             gui_loop
        option0:

        ;restore old terminal functionality
        call raw_mode_off

        mov             eax, 0
        mov             esp, ebp
        pop             ebp
        ret

raw_mode_on:

        push    ebp
        mov             ebp, esp

        push    raw_mode_on_cmd
        call    system
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

raw_mode_off:

        push    ebp
        mov             ebp, esp

        push    raw_mode_off_cmd
        call    system
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

init_board:

        push    ebp
        mov             ebp, esp

        ; FILE* and loop counter
        ; ebp-4, ebp-8
        sub             esp, 8

        ; open the file
        push    mode_r
        push    board_file
        call    fopen
        add             esp, 8
        mov             DWORD [ebp - 4], eax

        ; read the file data into the global buffer
        ; line-by-line so we can ignore the newline characters
        mov             DWORD [ebp - 8], 0
        read_loop:
        cmp             DWORD [ebp - 8], HEIGHT
        je              read_loop_end

                ; find the offset (WIDTH * counter)
                mov             eax, WIDTH
                mul             DWORD [ebp - 8]
        lea             ebx, [board + eax]

                ; read the bytes into the buffer
                push    DWORD [ebp - 4]
                push    WIDTH
                push    1
                push    ebx
                call    fread
                add             esp, 16

                ; slurp up the newline
                push    DWORD [ebp - 4]
                call    fgetc
                add             esp, 4

        inc             DWORD [ebp - 8]
        jmp             read_loop
        read_loop_end:

        ; close the open file handle
        push    DWORD [ebp - 4]
        call    fclose
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

render:

        push    ebp
        mov             ebp, esp

        ; two ints, for two loop counters
        ; ebp-4, ebp-8
        sub             esp, 8

        ; clear the screen
        push    clear_screen_code
        call    printf
        add             esp, 4

        ; print the help information
        push    help_str
        call    printf
        add             esp, 4

        ; outside loop by height
        ; i.e. for(c=0; c<height; c++)
        mov             DWORD [ebp - 4], 0
        y_loop_start:
        cmp             DWORD [ebp - 4], HEIGHT
        je              y_loop_end

                ; inside loop by width
                ; i.e. for(c=0; c<width; c++)
                mov             DWORD [ebp - 8], 0
                x_loop_start:
                cmp             DWORD [ebp - 8], WIDTH
                je              x_loop_end

                        ; check if (xpos,ypos)=(x,y)
                        mov             eax, DWORD [xpos]
                        cmp             eax, DWORD [ebp - 8]
                        jne             print_board
                        mov             eax, DWORD [ypos]
                        cmp             eax, DWORD [ebp - 4]
                        jne             print_board
                                ; if both were equal, print the player

                                mov             eax, DWORD [ebp - 4]
                                mov             ebx, WIDTH
                                mul             ebx
                                add             eax, DWORD [ebp - 8]
                                mov             ebx, 0
                                mov             bl, BYTE [board + eax]
                                push    ebx
                                push    cursor_str
                                call    printf
                                add             esp, 8

                                jmp             print_end
                        print_board:
                                ; otherwise print whatever's in the buffer
                                mov             eax, DWORD [ebp - 4]
                                mov             ebx, WIDTH
                                mul             ebx
                                add             eax, DWORD [ebp - 8]
                                mov             ebx, 0
                                mov             bl, BYTE [board + eax]
                                cmp             bl, WALL_CHAR
                                je              print_end
                                push    ebx
                                cmp             bl, COVEREDCHAR
                                je              cover
                                cmp             bl, EMPTYCHAR
                                je              empty
                                cmp             bl, FLAGGED
                                je              flagging
                                cmp             bl, MINECHAR
                                je              mine
                                cmp             bl, '1'
                                je              one
                                cmp             bl, '2'
                                je              two
                                cmp             bl, '3'
                                je              three
                                cmp             bl, '4'
                                je              four
                                cmp             bl, '5'
                                je              five
                                cmp             bl, '6'
                                je              six
                                cmp             bl, '7'
                                je              seven
                                cmp             bl, '8'
                                je              eight

                                cover:
                                push    covered_str
                                jmp             calling
                                empty:
                                push    empty_str
                                jmp             calling
                                flagging:
                                push    flag_str
                                jmp             calling
                                mine:
                                push    mine_str
                                jmp             calling
                                one:
                                push    one_str
                                jmp             calling
                                two:
                                push    two_str
                                jmp             calling
                                three:
                                push    three_str
                                jmp             calling
                                four:
                                push    four_str
                                jmp             calling
                                five:
                                push    five_str
                                jmp             calling
                                six:
                                push    six_str
                                jmp             calling
                                seven:
                                push    seven_str
                                jmp             calling
                                eight:
                                push    eight_str

                                calling:
                                call    printf
                                add             esp, 8
                        print_end:

                inc             DWORD [ebp - 8]
                jmp             x_loop_start
                x_loop_end:

                ; write a newline
                push    0x0a
                call    putchar
                add             esp, 4

                ; write a carriage return (necessary when in raw mode)
                push    0x0d
                call    putchar
                add             esp, 4

        inc             DWORD [ebp - 4]
        jmp             y_loop_start
        y_loop_end:

        mov             esp, ebp
        pop             ebp
        ret

game_is_won:
        push    ebp
        mov             ebp, esp

        mov             ecx, 0

        mov             esi, 0
        topx:
        cmp             esi, WIDTH
        jg              endx

                mov             edi, 0
                topy:
                cmp             edi, HEIGHT
                jg              endy

                        mov             eax, WIDTH
                        mul             edi
                        add             eax, esi
                        lea             eax, [board + eax]
                        cmp             BYTE [eax], COVEREDCHAR
                        je              count
                        cmp             BYTE [eax], FLAGGED
                        je              count
                        jmp             notcount

                                count:
                                inc             ecx

                        notcount:

                inc             edi
                jmp             topy
                endy:

        inc             esi
        jmp             topx
        endx:

        cmp             ecx, NUMBER_MINES
        jne             notwin

                mov             eax, 1
                jmp             afternot

        notwin:
                mov             eax, 0

        afternot:

        mov             esp, ebp
        pop             ebp
        ret

cascade:
        push    ebp
        mov             ebp, esp

        topcascadeloop:
        mov             ecx, 1

                mov             esi, 1
                topxloop:
                mov             eax, WIDTH
                dec             eax
                cmp             esi, eax
                jg              endxloop

                        mov             edi, 1
                        topyloop:
                        mov             eax, HEIGHT
                        dec             eax
                        cmp             edi, eax
                        jg              endyloop

                                mov             eax, WIDTH
                                mul             edi
                                add             eax, esi
                                lea             eax, [board + eax]
                                cmp             BYTE [eax], EMPTYCHAR
                                jne             endcascadeif

                                        mov             eax, WIDTH
                                        mov             ebx, edi
                                        dec             ebx
                                        mul             ebx
                                        add             eax, esi
                                        lea             edx, [board + eax]
                                        cmp             BYTE [edx], COVEREDCHAR
                                        jne             nextcascade1

                                                mov             ecx, 0
                                                lea             eax, [mboard + eax]
                                                mov             al, BYTE [eax]
                                                mov             BYTE [edx], al

                                        nextcascade1:
                                        mov             eax, WIDTH
                                        add             ebx, 2
                                        mul             ebx
                                        add             eax, esi
                                        lea             edx, [board + eax]
                                        cmp             BYTE [edx], COVEREDCHAR
                                        jne             nextcascade2

                                                mov             ecx, 0
                                                lea             eax, [mboard + eax]
                                                mov             al, BYTE [eax]
                                                mov             BYTE [edx], al

                                        nextcascade2:
                                        mov             eax, WIDTH
                                        mul             edi
                                        add             eax, esi
                                        inc             eax
                                        lea             ebx, [board + eax]
                                        cmp             BYTE [ebx], COVEREDCHAR
                                        jne             nextcascade3

                                                mov             ecx, 0
                                                lea             eax, [mboard + eax]
                                                mov             al, BYTE [eax]
                                                mov             BYTE [ebx], al

                                        nextcascade3:
                                        mov             eax, WIDTH
                                        mul             edi
                                        add             eax, esi
                                        dec             eax
                                        lea             ebx, [board + eax]
                                        cmp             BYTE [ebx], COVEREDCHAR
                                        jne             endcascadeif

                                                mov             ecx, 0
                                                lea             eax, [mboard + eax]
                                                mov             al, BYTE [eax]
                                                mov             BYTE [ebx], al

                                endcascadeif:

                        inc             edi
                        jmp             topyloop
                        endyloop:

                inc             esi
                jmp             topxloop
                endxloop:

        cmp             ecx, 0
        je              topcascadeloop
        endcascadeloop:

        mov             esp, ebp
        pop             ebp
        ret

get_nums:
        push    ebp
        mov             ebp, esp

        mov             edi, 1
        topnumloop:
        mov             eax, WIDTH
        dec             eax
        cmp             edi, eax
        jge             endnumloop

                mov             esi, 1
                topnumloop2:
                mov             eax, HEIGHT
                dec             eax
                cmp             esi, eax
                jge             endnumloop2

                        mov             dl, 0

                        ;XXX
                        ;XOX
                        ;XXX
                        ;checking the squares around the target square

                        mov             eax, WIDTH
                        mul             esi
                        sub             eax, WIDTH
                        add             eax, edi
                        dec             eax
                        lea             ebx, [mboard + eax]
                        cmp             BYTE [ebx], MINECHAR
                        jne             nextsquare1
                                inc             dl
                        nextsquare1:

                        inc             eax
                        lea             ebx, [mboard + eax]
                        cmp             BYTE [ebx], MINECHAR
                        jne             nextsquare2
                                inc             dl
                        nextsquare2:

                        inc             eax
                        lea             ebx, [mboard + eax]
                        cmp             BYTE [ebx], MINECHAR
                        jne             nextsquare3
                                inc             dl
                        nextsquare3:

                        add             eax, WIDTH
                        lea             ebx, [mboard + eax]
                        cmp             BYTE [ebx], MINECHAR
                        jne             nextsquare4
                                inc             dl
                        nextsquare4:

                        sub             eax, 2
                        lea             ebx, [mboard + eax]
                        cmp             BYTE [ebx], MINECHAR
                        jne             nextsquare5
                                inc             dl
                        nextsquare5:

                        add             eax, WIDTH
                        lea             ebx, [mboard + eax]
                        cmp             BYTE [ebx], MINECHAR
                        jne             nextsquare6
                                inc             dl
                        nextsquare6:

                        inc             eax
                        lea             ebx, [mboard + eax]
                        cmp             BYTE [ebx], MINECHAR
                        jne             nextsquare7
                                inc             dl
                        nextsquare7:

                        inc             eax
                        lea             ebx, [mboard + eax]
                        cmp             BYTE [ebx], MINECHAR
                        jne             nextsquare8
                                inc             dl
                        nextsquare8:

                        dec             eax
                        sub             eax, WIDTH
                        lea             ebx, [mboard + eax]
                        add             dl, '0'
                        cmp             BYTE [ebx], MINECHAR
                        je              skipmine
                                cmp             dl, '0'
                                jne             printnum
                                        mov             BYTE [ebx], EMPTYCHAR
                                        jmp             skipmine
                                printnum:
                                mov             BYTE [ebx], dl
                        skipmine:
                inc             esi
                jmp             topnumloop2
                endnumloop2:

        inc             edi
        jmp             topnumloop
        endnumloop:

        mov             esp, ebp
        pop             ebp
        ret

clear_mines:
        push    ebp
        mov             ebp, esp

        mov             edi, 1
        topclearloop:
        mov             eax, WIDTH
        dec             eax
        cmp             edi, eax
        jge             endclearloop

                mov             esi, 1
                topclearloop2:
                mov             eax, HEIGHT
                dec             eax
                cmp             esi, eax
                jge             endclearloop2

                        mov             eax, WIDTH
                        mul             esi
                        add             eax, edi
                        lea             eax, [mboard + eax]
                        mov             BYTE [eax], EMPTYCHAR

                inc             esi
                jmp             topclearloop2
                endclearloop2:

        inc             edi
        jmp             topclearloop
        endclearloop:

        mov             esp, ebp
        pop             ebp
        ret

get_mines:
        push    ebp
        mov             ebp, esp

        mov             edi, 0
        topmineloop:
        cmp             edi, NUMBER_MINES
        jge             endmineloop

                call    rand
                mov             ebx, WIDTH
                sub             ebx, 2
                cdq
                div             ebx
                inc             edx
                mov             esi, edx

                call    rand
                mov             ebx, HEIGHT
                sub             ebx, 2
                cdq
                div             ebx
                inc             edx

                mov             eax, WIDTH
                mul             edx
                add             eax, esi
                lea             eax, [mboard + eax]
                cmp             BYTE [eax], MINECHAR
                je              topmineloop

                        mov             BYTE [eax], MINECHAR

        inc             edi
        jmp             topmineloop
        endmineloop:

        mov             esp, ebp
        pop             ebp
        ret