# KEYBOARD and DISPLAY MMIO ----------------------------------------------------
.eqv KEY_CODE 0xFFFF0004  # ASCII code to show, 1 byte 
# BITMAP DISPLAY ----------------------------------------------------
.eqv MONITOR_SCREEN 0x10010000
.eqv YELLOW 0x00FFFF00
.eqv BLACK 0x00000000
#===============================================================================
#===============================================================================
.data
#Control code ------------------------------------------------------------------
	L :	.asciiz "a"
	R : .asciiz "d"
	U: 	.asciiz "w"
	D: 	.asciiz "s"   
#-------------------------------------------------------------------------------	
# Vẽ bóng tại tâm màn hình (x0, y0)
# a0 = x0 
# a1 = y0
# a2 = color
# a3 = radius
.text
	li $k0, KEY_CODE
	li $v1, MONITOR_SCREEN
#Giá trị ban đầu tại tâm
	li $a0, 256		
	li $a1, 256
	li $a3, 20	
	li $a2, YELLOW
	addi	$s7, $0, 512		#Chiều dài và chiều rộng di chuyển
	jal 	DrawCircle	
	nop
#----------------------------------------------------------------
# moving
# @brief		Thực hiện di chuyển bóng
# @param[in]	$t1	Kí tự điều khiển từ bàn phím
#----------------------------------------------------------------	
moving:	
	beq $t1,97,left		#$t1 = 'a'
	beq $t1,100,right	#$t1 = 'd'
	beq $t1,115,down	#$t1 = 's'
	beq $t1,119,up		#$t1 = 'w'
	j Input		
	left:	#Thực hiện di chuyển sang trái
		li $a2,BLACK	#color = black
		jal DrawCircle
		addi $a0,$a0,-1		#x0 = x0 - 1
		add $a1,$a1, $0		#y0 = y0
		li $a2, YELLOW		#color = yellow
		jal DrawCircle
		jal Pause
		bltu $a0,20,reboundRight	#Nếu x0 = 20 thì thực hiện bật phải
		j Input
	right: 	#Thực hiện di chuyển sang phải
		li $a2,BLACK	#color = black
		jal DrawCircle
		addi $a0,$a0,1		#x0 = x0 + 1
		add $a1,$a1, $0		#y0 = y0
		li $a2, YELLOW		#color = yellow
		jal DrawCircle
		jal Pause
		bgtu $a0,492,reboundLeft	#Nếu x0 = 512 - 20 = 492 thì thực hiện bật trái
		j Input
	up: 	#Thực hiện di chuyển lên trên
		li $a2,BLACK	#color = black
		jal DrawCircle		
		addi $a1,$a1,-1		#y0 = y0 - 1
		add $a0,$a0,$0		#x0 = x0
		li $a2, YELLOW		#color = yellow
		jal DrawCircle
		jal Pause
		bltu $a1,20,reboundDown		#Nếu y0 = 20 thì thực hiện đi xuống
		j Input
	down: 	#Thực hiện di chuyển xuống dưới
		li $a2,BLACK	#color = black
		jal DrawCircle
		addi $a1,$a1,1		#y0 = y0 + 1
		add $a0,$a0,$0		#x0 = x0
		li $a2, YELLOW		#color = yellow
		jal DrawCircle
		jal Pause
		bgtu $a1,492,reboundUp		#Nếu y0 = 512 - 20 = 492 thì thực hiện đi lên
		j Input
	reboundLeft:	#Thực hiện bật sang trái
		li $t3, 97	#Gán $t3 với 'a' rồi lưu vào địa chỉ $k0 
		sw $t3,0($k0)
		j Input	
	reboundRight:	#Thực hiện bật sang phải
		li $t3, 100	#Gán $t3 với 'd' rồi lưu vào địa chỉ $k0 
		sw $t3,0($k0)
		j Input	
	reboundDown:	#Thực hiện bật xuống dưới
		li $t3, 115	#Gán $t3 với 's' rồi lưu vào địa chỉ $k0 
		sw $t3,0($k0)
		j Input
	reboundUp:		#Thực hiện bật lên trên
		li $t3, 119	#Gán $t3 với 'w' rồi lưu vào địa chỉ $k0 
		sw $t3,0($k0)
		j Input
Input:	#Thực hiện đọc kí tự từ bàn phím  
	ReadKey: lw $t1, 0($k0) # $t1 = [$k0] = KEY_CODE
	j moving

Pause:	#vì thanh ghi $a0 trùng với biến số x0 nên để sử dụng syscall 32 thì dùng stack để lưu tạm thời giá trị $a0 
	addiu $sp,$sp,-4
	sw $a0, ($sp)
	li $a0, 0		# speed = 0ms
	li $v0, 32	 	#syscall sleep
	syscall
    
	lw $a0,($sp)		#tra lai gia tri $a0
	addiu $sp,$sp,4
	jr $ra
	
	
DrawCircle:#Using Midpoint Circle Algorithm
    	#MAKE ROOM ON STACK
    	addi $sp, $sp, -4      #Make room on stack for 1 words
   		sw  $ra, 0($sp)     #Store $ra on element 0 of stack
    	add $t0, $a3, $0            #x
    	add $t1, $0, $0              #y
    	add $t2, $0, $0              #e

    	#While(x >= y)
circleLoop:
    	blt $t0, $t1, Break    #If x < y, skip circleLoop

	#s5 = a0, s6 = a1
    	#Draw Dot (x0 + x, y0 + y)
    	addu $s5, $a0, $t0
    	addu $s6, $a1, $t1
    	jal  drawDot             #Jump to drawDot

        #Draw Dot (x0 + y, y0 + x)
        addu $s5, $a0, $t1
        addu $s6, $a1, $t0
        jal  drawDot             #Jump to drawDot

        #Draw Dot (x0 - y, y0 + x)
        subu $s5, $a0, $t1
        addu $s6, $a1, $t0
        jal  drawDot             #Jump to drawDot

        #Draw Dot (x0 - x, y0 + y)
        subu $s5, $a0, $t0
        addu $s6, $a1, $t1
        jal  drawDot             #Jump to drawDot

        #Draw Dot (x0 - x, y0 - y)
        subu $s5, $a0, $t0
        subu $s6, $a1, $t1
        jal  drawDot             #Jump to drawDot

        #Draw Dot (x0 - y, y0 - x)
        subu $s5, $a0, $t1
        subu $s6, $a1, $t0
        jal  drawDot             #Jump to drawDot

        #Draw Dot (x0 + y, y0 - x)
        addu $s5, $a0, $t1
        subu $s6, $a1, $t0
        jal  drawDot             #Jump to drawDot

        #Draw Dot (x0 + x, y0 - y)
        addu $s5, $a0, $t0
        subu $s6, $a1, $t1
        jal drawDot             #Jump to drawDot

    	IF:#If (err <= 0)
    	bgtz $t2, Else
    	addi $t1, $t1, 1     #y++
    	sll $t8, $t1, 1			#Bitshift y left 1	
    	addi $t8, $t8, 1		#2y + 1
    	addu $t2, $t2, $t8		#Add  e + (2y + 1)
    	j circleLoop      #Skip else stmt

    	#Else If (err > 0)
    	Else:
    	addi $t0, $t0, -1        #x--   	
	sll $t8, $t0, 1			#Bitshift x left 1
    	addi $t8, $t8, 1		#2x + 1
    	subu $t2, $t2, $t8		#Subtract e - (2x + 1)
	j circleLoop

Break:     

    	#RESTORE $RA
    	lw $ra, 0($sp)     #Restore $ra from stack
    	addiu $sp, $sp, 4        #Readjust stack
    	jr $ra
    	nop
drawDot:
    	add $s1, $s6, $0
    	sll $s1, $s1, 9        # calculate offset in $s1: s1 = y_pos * 512
    	add $s1, $s1, $s5       # s1 = y_pos * 512 + x_pos = "index"
    	sll $s1, $s1, 2         # s1 = (y_pos * 512 + x_pos)*4 = "offset"
    	add $s1, $s1, $v1       # s1 = v1 + offset
    	sw $a2, ($s1)          # draw it!
    	jr $ra
