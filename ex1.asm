# DIGITAL LAB SIM --------------------------------------------------------------
.eqv IN_ADDRESS_HEXA_KEYBOARD 0xFFFF0012
.eqv OUT_ADDRESS_HEXA_KEYBOARD 0xFFFF0014
# Key value --------------------------------------------------------------------
	.eqv KEY_0 0x11
	.eqv KEY_1 0x21
	.eqv KEY_2 0x41
	.eqv KEY_3 0x81
	.eqv KEY_4 0x12
	.eqv KEY_5 0x22
	.eqv KEY_6 0x42
	.eqv KEY_7 0x82
	.eqv KEY_8 0x14
	.eqv KEY_9 0x24
	.eqv KEY_a 0x44
	.eqv KEY_b 0x84
	.eqv KEY_c 0x18
	.eqv KEY_d 0x28
	.eqv KEY_e 0x48
	.eqv KEY_f 0x88
# KEYBOARD and DISPLAY MMIO ----------------------------------------------------
.eqv KEY_CODE 0xFFFF0004 	# ASCII code from keyboard, 1 byte
.eqv KEY_READY 0xFFFF0000 	# =1 if has a new keycode ?
 				# Auto clear after lw
# MARSBOT ----------------------------------------------------------------------
.eqv HEADING	0xffff8010	# Integer: An angle between 0 and 359
 				# 0 : North (up)
 				# 90: East (right)
				# 180: South (down)
				# 270: West (left)
.eqv MOVING 	0xffff8050 	# Boolean: whether or not to move
.eqv LEAVETRACK 	0xffff8020 	# Boolean (0 or non-0):
 				# whether or not to leave a track
.eqv WHEREX 	0xffff8030 	# Integer: Current x-location of MarsBot
.eqv WHEREY 	0xffff8040 	# Integer: Current y-location of MarsBot
#===============================================================================
#===============================================================================
.data
#Control code ------------------------------------------------------------------
	MOVE_CODE: .asciiz "1b4"
	STOP_CODE: .asciiz "c68"
	GO_LEFT_CODE: .asciiz "444"
	GO_RIGHT_CODE: .asciiz "666"
	TRACK_CODE: .asciiz "dad"
	UNTRACK_CODE: .asciiz "cbc"
	GO_BACK_CODE: .asciiz "999"
	WRONG_CODE: .asciiz "Wrong control code!"
#-------------------------------------------------------------------------------
	inputControlCode: .space 50
	lengthControlCode: .word 0
	nowHeading: .word 0
#-------------------------------------------------------------------------------
# Đường đi của Marsbot là một đường gấp khúc và được lưu vào mảng path theo từng khúc của đường đi
# Mỗi khúc là một đoạn thẳng - đoạn đường giữa hai lần rẽ của Marsbot
# Mỗi khúc được lưu dưới dạng 1 structure như sau: {x, y, z}
# trong đó: 	x, y là tọa độ điểm đầu tiên của khúc
#		z là hướng của khúc đó
# Lưu mỗi thành phần cần 4 bytes nên lưu 1 structure cần 3 (word) x 4 (bytes) = 12 bytes
# Mặc định:	Structure đầu tiên là {0,0,0}
# 		Độ dài đường đi ngay khi bắt đầu là 12 bytes
#-------------------------------------------------------------------------------
	path: .space 600
	lengthPath: .word 12		#bytes
#===============================================================================
#===============================================================================
.text	
main:
	li $k0, KEY_CODE
 	li $k1, KEY_READY
#---------------------------------------------------------
# Enable the interrupt of Keyboard matrix 4x4 of Digital Lab Sim
#---------------------------------------------------------
		li $t1, IN_ADDRESS_HEXA_KEYBOARD
		li $t3, 0x80 			# bit 7 = 1 to enable
		sb $t3, 0($t1)
#---------------------------------------------------------
loop:		
		nop
WaitForKey:	
		lw $t5, 0($k1)			# $t5 = [$k1] = KEY_READY
		beq $t5, $zero, WaitForKey	# Nếu $t5 == 0 thì tiếp tục Polling 
		nop
		beq $t5, $zero, WaitForKey
ReadKey:
		lw $t6, 0($k0)		 	# $t6 = [$k0] = KEY_CODE
		beq $t6, 127 , RemoveInputCode		# Nếu $t6 == Del key (mã Ascii: 127) thì xóa mã đang nhập
		bne $t6, '\n' , loop		# Nếu $t6 != '\n' thì tiếp tục Polling
		nop
CheckControlCode:				# Kiểm tra mã nhập vào để thực hiện điều khiển
		la $s2, lengthControlCode
		lw $s2, 0($s2)
		bne $s2, 3, pushErrorMess	# Nếu độ dài mã khác 3 thì báo mã lỗi
		
		la $s3, MOVE_CODE		# Kiểm tra có phải lệnh Move không
		jal isEqualString		# Nếu mã nhập vào là MOVE_CODE thì $t0 = 1, ngược lại $t0 = 0
		beq $t0, 1, go			# Nếu đúng là lệnh Move thì điều khiển Marsbot di chuyển
		
		la $s3, STOP_CODE		# Kiểm tra có phải lệnh Stop không
		jal isEqualString
		beq $t0, 1, stop
		
		la $s3, GO_LEFT_CODE		# Kiểm tra có phải lệnh Go Left không
		jal isEqualString
		beq $t0, 1, goLeft
		
		la $s3, GO_RIGHT_CODE		# Kiểm tra có phải lệnh Go Right không
		jal isEqualString
		beq $t0, 1, goRight
		
		la $s3, TRACK_CODE		# Kiểm tra có phải lệnh Track không
		jal isEqualString
		beq $t0, 1, track
		
		la $s3, UNTRACK_CODE		# Kiểm tra có phải lệnh Untrack không
		jal isEqualString
		beq $t0, 1, untrack
		
		la $s3, GO_BACK_CODE		# Kiểm tra có phải lệnh Go Back không
		jal isEqualString
		beq $t0, 1, goBack
		
		beq $t0, 0, pushErrorMess	# Báo lỗi nếu mã nhập vào không phải tất cả các lệnh trên
PrintControlCode:				# In mã điều khiển vừa nhập
		li $v0, 4
		la $a0, inputControlCode
		syscall
		nop	
RemoveInputCode:					# Xóa mã vừa nhập
		jal removeControlCode			
		nop

		j loop
#----------------------------------------------------------------
# isEqualString
# @brief		Kiểm tra mã vừa nhập có giống một mã điều khiển nào đó không
# @param[in]	$s1	Địa chỉ của mã vừa nhập
# @param[in]	$s3	Địa chỉ của mã điều khiển để so sánh với mã vừa nhập
# @param[out] 	$t0	Bằng 1 nếu hai mã giống nhau, bằng 0 nếu hai mã đó khác nhau
#----------------------------------------------------------------					
isEqualString:
		#backup
		addi $sp,$sp,4
		sw $t1, 0($sp)
		addi $sp,$sp,4
		sw $s1, 0($sp)
		addi $sp,$sp,4
		sw $t2, 0($sp)
		addi $sp,$sp,4
		sw $t3, 0($sp)	
	
		#processing
		add $t0, $zero, $zero		# $t0 = 0
		addi $t1, $zero, 0		# $t1 = i = 0
		la $s1, inputControlCode		# $s1 = inputControlCode
		for_loop_to_check_equal:		# So sánh từng ký tự của inputControlCode với mã điều khiển s ở $s3	
			add $t2, $s1, $t1			# $t2 = inputControlCode + i
			lb $t2, 0($t2)				# $t2 = inputControlCode[i]	
			add $t3, $s3, $t1			# $t3 = s + i
			lb $t3, 0($t3)				# $t3 = s[i]
			addi $t1, $t1, 1			 	# i++		
			bne $t2, $t3, isNotEqual			# Nếu $t2 != $t3 -> mã khác nhau
			bne $t1, 3, for_loop_to_check_equal	# Nếu $t1 != 3 thì tiếp tục kiểm tra
isEqual:
		#restore
		lw $t3, 0($sp)
		addi $sp,$sp,-4
		lw $t2, 0($sp)
		addi $sp,$sp,-4
		lw $s1, 0($sp)
		addi $sp,$sp,-4
		lw $t1, 0($sp)
		addi $sp,$sp,-4
	
		add $t0, $zero, 1		# Cập nhật $t0 = 1
		jr $ra
		nop
isNotEqual:
		#restore
		lw $t3, 0($sp)
		addi $sp,$sp,-4
		lw $t2, 0($sp)
		addi $sp,$sp,-4
		lw $s1, 0($sp)
		addi $sp,$sp,-4
		lw $t1, 0($sp)
		addi $sp,$sp,-4

		add $t0, $zero, $zero		# Cập nhật $t0 = 0
		jr $ra
		nop
#----------------------------------------------------------------
# go
# @brief		Điều khiển Marsbot bắt đầu chuyển động và in mã điều khiển
#----------------------------------------------------------------
go: 	
		jal GO
		j PrintControlCode
#----------------------------------------------------------------
# stop
# @brief		Điều khiển Marsbot đứng im và in mã điều khiển
#----------------------------------------------------------------
stop: 		jal STOP
		j PrintControlCode
#----------------------------------------------------------------
# track
# @brief		Điều khiển Marsbot bắt đầu để lại vết trên đường và in mã điều khiển
#----------------------------------------------------------------
track: 		jal TRACK
		j PrintControlCode
#----------------------------------------------------------------
# untrack
# @brief		Điều khiển Marsbot chấm dứt để lại vết trên đường và in mã điều khiển
#----------------------------------------------------------------
untrack: 	jal UNTRACK
		j PrintControlCode
#----------------------------------------------------------------
# goLeft
# @brief		Điều khiển Marsbot rẽ trái và in mã điều khiển
# @param[in]	$s6	Hướng hiện tại của Marsbot
# param[out] 	$s6	Hướng sau khi rẽ của Marsbot
#----------------------------------------------------------------	
goLeft:	
		#backup
		addi $sp,$sp,4
		sw $s5, 0($sp)
		addi $sp,$sp,4
		sw $s6, 0($sp)
		#processing
		jal  UNTRACK 			# ngắt track cũ		
		nop
		jal  TRACK 			# vẽ track từ vị trí mới		
		nop
		la $s5, nowHeading
		lw $s6, 0($s5)			# $s6 là hướng hiện tại
		addi $s6, $s6, -90 		# giảm hướng đi 90* = quay sang trái
		sw $s6, 0($s5) 			# cập nhật nowHeading
		#restore
		lw $s6, 0($sp)
		addi $sp,$sp,-4
		lw $s5, 0($sp)
		addi $sp,$sp,-4
	
		jal storePath			# lưu lại đường đi
		jal ROTATE			# xoay Marsbot
		j PrintControlCode
#----------------------------------------------------------------
# goRight
# @brief		Điều khiển Marsbot rẽ phải và in mã điều khiển
# @param[in]	$s6	Hướng hiện tại của Marsbot
# param[out] 	$s6	Hướng sau khi rẽ của Marsbot
#----------------------------------------------------------------
goRight:
		#backup
		addi $sp,$sp,4
		sw $s5, 0($sp)
		addi $sp,$sp,4
		sw $s6, 0($sp)
		#restore
		jal  UNTRACK 			# ngắt track cũ		
		nop
		jal  TRACK 			# vẽ track từ vị trí mới		
		nop
		la $s5, nowHeading
		lw $s6, 0($s5)			# $s6 là hướng hiện tại
		addi $s6, $s6, 90 		# tăng hướng thêm 90* = quay sang phải
		sw $s6, 0($s5) 			# cập nhật nowHeading
		#restore
		lw $s6, 0($sp)
		addi $sp,$sp,-4
		lw $s5, 0($sp)
		addi $sp,$sp,-4
	
		jal storePath			# lưu lại đường đi
		jal ROTATE			# xoay Marsbot
		j PrintControlCode			
#----------------------------------------------------------------
# goBack
# @brief		Điều khiển Marsbot đi ngược lại đường đi cũ
# @param[in]	$s5		Độ dài của biến path đường đi  
# @param[in]	$s7		Biến lưu đường đi của MarsBot
# @param[out]			Marsbot dừng lại ở vị trí ban đầu
#----------------------------------------------------------------
goBack:
		#backup
		addi $sp,$sp,4
		sw $s5, 0($sp)
		addi $sp,$sp,4
		sw $s6, 0($sp)
		addi $sp,$sp,4
		sw $s7, 0($sp)
		addi $sp,$sp,4
		sw $t6, 0($sp)
		addi $sp,$sp,4
		sw $t7, 0($sp)
		addi $sp,$sp,4
		sw $t8, 0($sp)
		addi $sp,$sp,4
		sw $t9, 0($sp)
		
		jal UNTRACK
		la $s7, path
		la $s5, lengthPath
		lw $s5, 0($s5)
		add $s7, $s7, $s5
	begin:
		addi $s5, $s5, -12 		# giảm độ dài đường đi lengthPath đi 12 bytes
		addi $s7, $s7, -12		# lùi về vị trí chứa thông tin về khúc cuối cùng
		lw $s6, 8($s7)			# hướng của khúc cuối cùng
		addi $s6, $s6, 180		# tăng hướng thêm 180* = quay ngược lại hướng của khúc cuối cùng
		la   $t7,  nowHeading		
		sw   $s6,  0($t7)		# cập nhật hướng mới
		jal ROTATE			# quay Marsbot ngược lại
		lw   $t8,  0($s7)		# tọa độ x của điểm đầu tiên của một khúc trong đường đi
		lw   $t9,  4($s7)		# tọa độ y của điểm đầu tiên của một khúc trong đường đi
		jal  GO
	go_to_first_point_of_edge:	
		li   $t6,  WHEREX		
		lw   $t6,  0($t6)		# tọa độ x hiện tại
		bne  $t6,  $t8,  go_to_first_point_of_edge
		nop

		li   $t7,  WHEREY		
		lw   $t7,  0($t7)		# tọa độ y hiện tại
		bne  $t7,  $t9, go_to_first_point_of_edge
		nop
	
		jal  STOP
		bne  $s5, 0, begin
		nop
	
	finish:
		jal STOP
		la $t8, nowHeading
		add $s6, $zero, $zero
		sw $s6, 0($t8)			# cập nhật hướng
		la $t8, lengthPath
		addi $s5, $zero, 12
		sw $s5, 0($t8)			# cập nhật độ dài đường đi lengthPath = 12

		#restore
		lw $t9, 0($sp)
		addi $sp,$sp,-4
		lw $t8, 0($sp)
		addi $sp,$sp,-4
		lw $t7, 0($sp)
		addi $sp,$sp,-4
		lw $t6, 0($sp)
		addi $sp,$sp,-4
		lw $s7, 0($sp)
		addi $sp,$sp,-4
		lw $s6, 0($sp)
		addi $sp,$sp,-4
		lw $s5, 0($sp)
		addi $sp,$sp,-4
		
		j PrintControlCode
#-----------------------------------------------------------
# GO procedure, to start running
# param[in] none
#-----------------------------------------------------------
GO: 		#backup
		addi $sp,$sp,4
		sw $at,0($sp)
		addi $sp,$sp,4
		sw $k0,0($sp)
		#processing
		li $at, MOVING # change MOVING port
 		addi $k0, $zero, 1 # to logic 1,
		sb $k0, 0($at) # to start running	
		#restore
		lw $k0, 0($sp)
		addi $sp,$sp,-4
		lw $at, 0($sp)
		addi $sp,$sp,-4
	
		jr $ra
		nop
#-----------------------------------------------------------
# STOP procedure, to stop running
# param[in] none
#-----------------------------------------------------------
STOP: 		#backup
		addi $sp,$sp,4
		sw $at,0($sp)
		#processing
		li $at, MOVING # change MOVING port to 0
		sb $zero, 0($at) # to stop
		#restore
		lw $at, 0($sp)
		addi $sp,$sp,-4
	
		jr $ra
		nop
#-----------------------------------------------------------
# TRACK procedure, to start drawing line
# param[in] none
#-----------------------------------------------------------
TRACK: 		#backup
		addi $sp,$sp,4
		sw $at,0($sp)
		addi $sp,$sp,4
		sw $k0,0($sp)
		#processing
		li $at, LEAVETRACK # change LEAVETRACK port
		addi $k0, $zero,1 # to logic 1,
 		sb $k0, 0($at) # to start tracking
 		#restore
		lw $k0, 0($sp)
		addi $sp,$sp,-4
		lw $at, 0($sp)
		addi $sp,$sp,-4
	
 		jr $ra
		nop
#-----------------------------------------------------------
# UNTRACK procedure, to stop drawing line
# param[in] none
#-----------------------------------------------------------
UNTRACK:		#backup
		addi $sp,$sp,4
		sw $at,0($sp)
		#processing
		li $at, LEAVETRACK # change LEAVETRACK port to 0
 		sb $zero, 0($at) # to stop drawing tail
 		#restore
		lw $at, 0($sp)
		addi $sp,$sp,-4
	
 		jr $ra
		nop
#----------------------------------------------------------------
# ROTATE procedure, to rotate the robot 
# param[in] 	$a0, An angle between 0 and 359 
# 		     0 : North (up) 
# 		     90 : East (right) 
# 		     180 : South (down) 
# 		     270 : West (left)
#----------------------------------------------------------------	
ROTATE: 		#backup
		addi $sp,$sp,4
		sw $t1,0($sp)
		addi $sp,$sp,4
		sw $t2,0($sp)
		addi $sp,$sp,4
		sw $t3,0($sp)
		#processing
		li $t1, HEADING # change HEADING port
		la $t2, nowHeading
		lw $t3, 0($t2)	#$t3 is hướng at now
 		sw $t3, 0($t1) # to rotate robot
 		#restore
 		lw $t3, 0($sp)
		addi $sp,$sp,-4
		lw $t2, 0($sp)
		addi $sp,$sp,-4
		lw $t1, 0($sp)
		addi $sp,$sp,-4
	
 		jr $ra
		nop				
#----------------------------------------------------------------
# storePath
# @brief		Lưu đường đi của Marsbol vào biến mảng path
# @param[in]	$s1		Tọa độ x hiện tại của MarsBot
# @param[in]	$s2		Tọa độ y hiện tại của MarsBot
# @param[in]	$s4		Hướng hiện tại của Marsbot
# @param[out]	$s3		Độ dài của biến path đường đi  
# @param[out]	$t4		Biến lưu đường đi của MarsBot
#----------------------------------------------------------------
storePath:
		#backup
		addi $sp,$sp,4
		sw $t1, 0($sp)
		addi $sp,$sp,4
		sw $t2, 0($sp)
		addi $sp,$sp,4
		sw $t3, 0($sp)
		addi $sp,$sp,4
		sw $t4, 0($sp)
		addi $sp,$sp,4
		sw $s1, 0($sp)
		addi $sp,$sp,4
		sw $s2, 0($sp)
		addi $sp,$sp,4
		sw $s3, 0($sp)
		addi $sp,$sp,4
		sw $s4, 0($sp)
	
		#processing
		li $t1, WHEREX
		lw $s1, 0($t1)			# Lấy tọa độ x hiện tại của Marsbot: $s1 = x
		li $t2, WHEREY	
		lw $s2, 0($t2)			# Lấy tọa độ y hiện tại của Marsbot: $s2 = y
	
		la $s4, nowHeading
		lw $s4, 0($s4)			# Lấy hướng hiện tại của Marsbot: $s4 = nowHeading

		la $t3, lengthPath
		lw $s3, 0($t3)			# $s3 = lengthPath
	
		la $t4, path
		add $t4, $t4, $s3		# Đi đến cuối mảng path để bắt đầu lưu
	
		sw $s1, 0($t4)			# Lưu x
		sw $s2, 4($t4)			# Lưu y
		sw $s4, 8($t4)			# Lưu hướng
	
		addi $s3, $s3, 12		# Cập nhật lengthPath += 12
		sw $s3, 0($t3)
	
		#restore
		lw $s4, 0($sp)
		addi $sp,$sp,-4
		lw $s3, 0($sp)
		addi $sp,$sp,-4
		lw $s2, 0($sp)
		addi $sp,$sp,-4
		lw $s1, 0($sp)
		addi $sp,$sp,-4
		lw $t4, 0($sp)
		addi $sp,$sp,-4
		lw $t3, 0($sp)
		addi $sp,$sp,-4
		lw $t2, 0($sp)
		addi $sp,$sp,-4
		lw $t1, 0($sp)
		addi $sp,$sp,-4
	
		jr $ra
		nop		
#----------------------------------------------------------------
# pushErrorMess
# @brief		Thông báo mã điều khiển nhập vào bị sai và in mã đó ra console
# @param[in]	$a0	Địa chỉ của mã vừa nhập
#----------------------------------------------------------------			
pushErrorMess:
		li $v0, 4
		la $a0, inputControlCode
		syscall
		nop
	
		li $v0, 55
		la $a0, WRONG_CODE
		syscall
		nop
	
		j RemoveInputCode
		nop
#----------------------------------------------------------------
# removeControlCode
# @brief		Xóa toàn bộ mã điều khiển đang nhập
# @param[in]	$t3	Độ dài mã điều khiển đang nhập
# @param[in]	$s1	Địa chỉ lưu mã điều khiển đang nhập
# param[out] 		Mã điều khiển đang nhập được xóa thành chuỗi rỗng, inputControlCode = ""
#----------------------------------------------------------------			
removeControlCode:
		#backup
		addi $sp,$sp,4
		sw $t1, 0($sp)
		addi $sp,$sp,4
		sw $t2, 0($sp)
		addi $sp,$sp,4
		sw $s1, 0($sp)
		addi $sp,$sp,4
		sw $t3, 0($sp)
		addi $sp,$sp,4
		sw $s2, 0($sp)
	
		#processing
		la $s2, lengthControlCode
		lw $t3, 0($s2)			# $t3 = lengthControlCode
		addi $t1, $zero, 0		# $t1 = i = 0
		addi $t2, $zero, 0		# $t2 = '\0'
		la $s1, inputControlCode
		for_loop_to_remove:
			sb $t2, 0($s1)		# xóa mã điều khiển bằng cách gán inputControlCode[i] = '\0'
			addi $t1, $t1, 1		# i++
			add $s1, $s1, 1		# $s1 = inputControlCode[i]				
			bne $t1, $t3, for_loop_to_remove	# nếu $t1 <= 3 tiếp tục xóa các ký tự tiếp theo
			nop
		
		add $t3, $zero, $zero			
		sw $t3, 0($s2)				# cập nhật lengthControlCode = 0

		#restore
		lw $s2, 0($sp)
		addi $sp,$sp,-4
		lw $t3, 0($sp)
		addi $sp,$sp,-4
		lw $s1, 0($sp)
		addi $sp,$sp,-4
		lw $t2, 0($sp)
		addi $sp,$sp,-4
		lw $t1, 0($sp)
		addi $sp,$sp,-4
	
		jr $ra
		nop
#===============================================================================
# GENERAL INTERRUPT SERVED ROUTINE for all interrupts
# Chương trình con xử lý ngắt khi có phím được nhấn để nhập mã điều khiển hoặc kích hoạt mã điều khiển
# Quét để tìm phím được nhấn và lưu ký tự tương ứng phím đó vào inputControlCode
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.ktext 0x80000180
#-------------------------------------------------------
# SAVE the current REG FILE to stack
#-------------------------------------------------------
backup: 
		addi $sp,$sp,4
		sw $ra,0($sp)
		addi $sp,$sp,4
		sw $t1,0($sp)
		addi $sp,$sp,4
		sw $t2,0($sp)
		addi $sp,$sp,4
		sw $t3,0($sp)
		addi $sp,$sp,4
		sw $a0,0($sp)
		addi $sp,$sp,4
		sw $at,0($sp)
		addi $sp,$sp,4
		sw $s0,0($sp)
		addi $sp,$sp,4
		sw $s1,0($sp)
		addi $sp,$sp,4
		sw $s2,0($sp)
		addi $sp,$sp,4
		sw $t4,0($sp)
		addi $sp,$sp,4
		sw $s3,0($sp)
#--------------------------------------------------------
# Processing
#--------------------------------------------------------
#----------------------------------------------------------------
# get_cod
# @brief		Quét tìm phím được nhấn và chuyển từ mã của phím đó sang mã ký tự tương ứng
# @param[out]	$a0	Mã hexa của phím được nhấn
# @param[out]	$s0 	Mã ASCII của ký tự tương ứng với phím được nhấn
#----------------------------------------------------------------
get_cod:
		li $t1, IN_ADDRESS_HEXA_KEYBOARD
		li $t2, OUT_ADDRESS_HEXA_KEYBOARD
scan_row1:
		li $t3, 0x81
		sb $t3, 0($t1)
		lbu $a0, 0($t2)
		bnez $a0, get_code_in_char
scan_row2:
		li $t3, 0x82
		sb $t3, 0($t1)
		lbu $a0, 0($t2)
		bnez $a0, get_code_in_char
scan_row3:
		li $t3, 0x84
		sb $t3, 0($t1)
		lbu $a0, 0($t2)
		bnez $a0, get_code_in_char
scan_row4:
		li $t3, 0x88
		sb $t3, 0($t1)
		lbu $a0, 0($t2)
		bnez $a0, get_code_in_char
get_code_in_char:
		beq $a0, KEY_0, case_0
		beq $a0, KEY_1, case_1
		beq $a0, KEY_2, case_2
		beq $a0, KEY_3, case_3
		beq $a0, KEY_4, case_4
		beq $a0, KEY_5, case_5
		beq $a0, KEY_6, case_6
		beq $a0, KEY_7, case_7
		beq $a0, KEY_8, case_8
		beq $a0, KEY_9, case_9
		beq $a0, KEY_a, case_a
		beq $a0, KEY_b, case_b
		beq $a0, KEY_c, case_c
		beq $a0, KEY_d, case_d
		beq $a0, KEY_e, case_e
		beq $a0, KEY_f, case_f
		
case_0:		li $s0, '0'
		j store_code
case_1:		li $s0, '1'
		j store_code
case_2:		li $s0, '2'
		j store_code
case_3:		li $s0, '3'
		j store_code
case_4:		li $s0, '4'
		j store_code
case_5:		li $s0, '5'
		j store_code
case_6:		li $s0, '6'
		j store_code
case_7:		li $s0, '7'
		j store_code
case_8:		li $s0, '8'
		j store_code
case_9:		li $s0, '9'
		j store_code
case_a:		li $s0, 'a'
		j store_code
case_b:		li $s0, 'b'
		j store_code
case_c:		li $s0, 'c'
		j store_code
case_d:		li $s0, 'd'
		j store_code
case_e:		li $s0,	'e'
		j store_code
case_f:		li $s0, 'f'
		j store_code
#----------------------------------------------------------------
# store_code
# @brief		Lưu ký tự vừa nhấn ở Digital Lab Sim vào xâu mã điều khiển nhập vào (inputControlCode)
# @param[in]	$s0 	Mã ASCII của ký tự tương ứng với phím vừa được nhấn
# @param[in]	$s1	Địa chỉ mã điều khiển đang nhập
# @param[in] 	$s3	Độ dài mã điều khiển đang nhập
#----------------------------------------------------------------
store_code:
		la $s1, inputControlCode
		la $s2, lengthControlCode
		lw $s3, 0($s2)			# $s3 = độ dài xâu inputControlCode

		add $s1, $s1, $s3		# Đi đến cuối xâu inputControlCode
		sb  $s0, 0($s1)			# inputControlCode[i] = $s0
		
		addi $s0, $zero, '\n'		# Thêm '\n' vào cuối xâu inputControlCode
		addi $s1, $s1, 1	
		sb  $s0, 0($s1)
		
		addi $s3, $s3, 1
		sw $s3, 0($s2)			# Cập nhật lengthControlCode += 1
#--------------------------------------------------------
# Evaluate the return address of main routine
# epc <= epc + 4
#--------------------------------------------------------
next_pc:
		mfc0 $at, $14 			# $at <= Coproc0.$14 = Coproc0.epc
		addi $at, $at, 4 		# $at = $at + 4 (next instruction)
		mtc0 $at, $14 			# Coproc0.$14 = Coproc0.epc <= $at
#--------------------------------------------------------
# RESTORE the REG FILE from STACK
#--------------------------------------------------------
restore:
		lw $s3, 0($sp)
		addi $sp,$sp,-4
		lw $t4, 0($sp)
		addi $sp,$sp,-4
		lw $s2, 0($sp)
		addi $sp,$sp,-4
		lw $s1, 0($sp)
		addi $sp,$sp,-4
		lw $s0, 0($sp)
		addi $sp,$sp,-4
		lw $at, 0($sp)
		addi $sp,$sp,-4
		lw $a0, 0($sp)
		addi $sp,$sp,-4
		lw $t3, 0($sp)
		addi $sp,$sp,-4
		lw $t2, 0($sp)
		addi $sp,$sp,-4
		lw $t1, 0($sp)
		addi $sp,$sp,-4
		lw $ra, 0($sp)
		addi $sp,$sp,-4
return: 		eret 				# Return from exception
