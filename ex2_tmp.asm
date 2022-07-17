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



moving:		
	beq $t1,97,left		
	beq $t1,100,right	
	beq $t1,115,down	
	beq $t1,119,up		
	j Input		
	
	left:	
		li $a2,BLACK	
		jal DrawCircle
		addi $a0,$a0,-1		
		add $a1,$a1, $0		
		li $a2, YELLOW		
		jal DrawCircle
		jal Pause
		bltu $a0,20,reboundRight	
		j Input
		
	reboundLeft:	
		li $t3, 97	
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
		
		
Input:	
	ReadKey: lw $t1, 0($k0) 
	j moving


Pause:	
	addiu $sp,$sp,-4
	sw $a0, ($sp)
	li $a0, 0		
	li $v0, 32	 	
	syscall
    
	lw $a0,($sp)		
	addiu $sp,$sp,4
	jr $ra
	
	
DrawCircle:
    	addi $sp, $sp, -4      
   	sw $ra, 0($sp)     
    	add $t0, $a3, $0           
    	add $t1, $0, $0            
    	add $t2, $0, $0             

    	
circleLoop:
    	blt $t0, $t1, Break    
    	addu $s5, $a0, $t0
    	addu $s6, $a1, $t1
    	jal  drawDot                       

    	IF:
    	bgtz $t2, Else
    	addi $t1, $t1, 1     
    	sll $t8, $t1, 1				
    	addi $t8, $t8, 1		
    	addu $t2, $t2, $t8		
    	j circleLoop      

    	Else:
    	addi $t0, $t0, -1        	
	sll $t8, $t0, 1			
    	addi $t8, $t8, 1		
    	subu $t2, $t2, $t8		
	j circleLoop

Break:     
    	lw $ra, 0($sp)     
    	addiu $sp, $sp, 4        
    	jr $ra
    	nop
drawDot:
    	add $s1, $s6, $0
    	sll $s1, $s1, 9        
    	add $s1, $s1, $s5       
    	sll $s1, $s1, 2         
    	add $s1, $s1, $v1       
    	sw $a2, ($s1)          
    	jr $ra
