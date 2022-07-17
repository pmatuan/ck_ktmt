.eqv KEY_CODE 0xFFFF0004  # ASCII code to show, 1 byte 
.eqv MONITOR_SCREEN 0x10010000
.eqv YELLOW 0x00FFFF00
.eqv BLACK 0x00000000
.data
L :	.asciiz "a"
R : 	.asciiz "d"
U: 	.asciiz "w"
D: 	.asciiz "s"   
	

#Vẽ bóng tại tâm màn hình (x0, y0)
#a0 = x0 
#a1 = y0
#a2 = color
#a3 = radius
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
moving:		#Thực hiện di chuyển bóng
	beq $t0,97,left		#$t0 = 'a'
	beq $t0,100,right	#$t0 = 'd'
	beq $t0,115,down	#$t0 = 's'
	beq $t0,119,up		#$t0 = 'w'
	j Input		
	left:	#Thuc hien di chuyen sang trai
		li $a2,BLACK	#color = black
		jal DrawCircle
		addi $a0,$a0,-1		#x0 = x0 - 1
		add $a1,$a1, $0		#y0 = y0
		li $a2, YELLOW		#color = yellow
		jal DrawCircle
		jal Pause
		bltu $a0,20,reboundRight	#Neu x0 = 20 tuc den thanh trai thi thu hien bat phai
		j Input
	right: 	#Thuc hien di chuyen sang phai
		li $a2,BLACK	#color = black
		jal DrawCircle
		addi $a0,$a0,1		#x0 = x0 + 1
		add $a1,$a1, $0		#y0 = y0
		li $a2, YELLOW		#color = yellow
		jal DrawCircle
		jal Pause
		bgtu $a0,492,reboundLeft	#Neu x0 = 512 - 20 = 492 tuc den thanh phai thi thu hien bat trai
		j Input
	up: 	#Thuc hien di chuyen len tren
		li $a2,BLACK	#color = black
		jal DrawCircle		
		addi $a1,$a1,-1		#y0 = y0 - 1
		add $a0,$a0,$0		#x0 = x0
		li $a2, YELLOW		#color = yellow
		jal DrawCircle
		jal Pause
		bltu $a1,20,reboundDown		#Neu y0 = 20 tuc den thanh tren cung thi thu hien bat xuong
		j Input
	down: 	#Thuc hien di chuyen xuong duoi
		li $a2,BLACK	#color = black
		jal DrawCircle
		addi $a1,$a1,1		#y0 = y0 + 1
		add $a0,$a0,$0		#x0 = x0
		li $a2, YELLOW		#color = yellow
		jal DrawCircle
		jal Pause
		bgtu $a1,492,reboundUp		#Neu y0 = 512 - 20 = 492 tuc den thanh duoi cung thi thu hien bat len
		j Input
	reboundLeft:	#Thuc hien bat sang trai
		li $t3, 97	#Gan $t3 voi 'a' roi luu vao dia chi $k0 
		sw $t3,0($k0)
		j Input	
	reboundRight:	#Thuc hien bat sang phai
		li $t3, 100	#Gan $t3 voi 'd' roi luu vao dia chi $k0 
		sw $t3,0($k0)
		j Input	
	reboundDown:	#Thuc hien bat xuong duoi
		li $t3, 115	#Gan $t3 voi 's' roi luu vao dia chi $k0 
		sw $t3,0($k0)
		j Input
	reboundUp:	#Thuc hien bat len tren
		li $t3, 119	#Gan $t3 voi 'w' roi luu vao dia chi $k0 
		sw $t3,0($k0)
		j Input
Input:	#Thuc hien doc ki tu tu ban phim nhap vao bang cach luu vao thanh ghi $t0
	ReadKey: lw $t0, 0($k0) # $t0 = [$k0] = KEY_CODE
	j moving

Pause:	#vi thanh ghi $a0 trung voi bien so x0 nen de syscall 32 thi phai su dung stack de luu tam thoi gia tri $a0
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
    	addi        $sp, $sp, -4      #Make room on stack for 1 words
   	sw      $ra, 0($sp)     #Store $ra on element 0 of stack
    	add $t1, $a3, $0            #x
    	add $t0, $0, $0              #y
    	add $t2, $0, $0              #Err

    	#While(x >= y)
circleLoop:
    	blt $t1, $t0, Break    #If x < y, skip circleLoop

	#s5 = a0, s6 = a1
    	#Draw Dot (x0 + x, y0 + y)
    	addu $s5, $a0, $t1
    	addu $s6, $a1, $t0
    	jal  drawDot             #Jump to drawDot

        #Draw Dot (x0 + y, y0 + x)
        addu $s5, $a0, $t0
        addu $s6, $a1, $t1
        jal  drawDot             #Jump to drawDot

        #Draw Dot (x0 - y, y0 + x)
        subu $s5, $a0, $t0
        addu $s6, $a1, $t1
        jal  drawDot             #Jump to drawDot

        #Draw Dot (x0 - x, y0 + y)
        subu $s5, $a0, $t1
        addu $s6, $a1, $t0
        jal  drawDot             #Jump to drawDot

        #Draw Dot (x0 - x, y0 - y)
        subu $s5, $a0, $t1
        subu $s6, $a1, $t0
        jal  drawDot             #Jump to drawDot

        #Draw Dot (x0 - y, y0 - x)
        subu $s5, $a0, $t0
        subu $s6, $a1, $t1
        jal  drawDot             #Jump to drawDot

        #Draw Dot (x0 + y, y0 - x)
        addu $s5, $a0, $t0
        subu $s6, $a1, $t1
        jal  drawDot             #Jump to drawDot

        #Draw Dot (x0 + x, y0 - y)
        addu $s5, $a0, $t1
        subu $s6, $a1, $t0
        jal drawDot             #Jump to drawDot

    	IF:#If (err <= 0)
    	bgtz $t2, Else
    	addi $t0, $t0, 1     #y++
    	sll $t8, $t0, 1			#Bitshift y left 1	
    	addi $t8, $t8, 1		#2y + 1
    	addu $t2, $t2, $t8		#Add  e + (2y + 1)
    	j circleLoop      #Skip else stmt

    	#Else If (err > 0)
    	Else:
    	addi $t1, $t1, -1        #x--   	
	sll $t8, $t1, 1			#Bitshift x left 1
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
