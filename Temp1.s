
.align 2
bunnies_data: .space 484

# .text
# main:
    # go wild
    # the world is your oyster :)
#	li $t0, 10
#	sw $t0, VELOCITY
#	j   main

.text
main:
	# enable interrupts
        li      $t4, TIMER_MASK     		# timer interrupt enable bit
        or      $t4, $t4, BONK_MASK 		# bonk interrupt bit
	or	$t4, $t4, BUNNY_MOVE_INT_MASK 	# jump interrupt bit
        or      $t4, $t4, 1             	# global interrupt enable
        mtc0    $t4, $12                	# set interrupt mask (Status register)

	li $s0, 0			# $s0 = units of weight we've collected
	li $s1, 0			# $s1 = number of rabbits we've collected
	lw $t0, PLAYPEN_LOCATION	# 32 bits containing x and y location of playpen
					# [31:16] is x, [15:0] is y
	and $s2, $t0, 0x0fff0000	# $s2 = x location of playpen
	srl $s2, $s2, 16
	and $s3, $t0, 0x00000fff	# $s3 = y location of pen
	
	j find_nearest_rabbit_start

find_nearest_rabbit_start:
	sw $0, VELOCITY
	la $s7, bunnies_data
	sw $s7, SEARCH_BUNNIES
	
	lw $t1, BOT_X			# $t1 = BOT_X
	lw $t2, BOT_Y			# $t2 = BOT_Y
	li $t5, 1000			# $t5 = the distance of the current closest rabbit
	la $t6, SEARCH_BUNNIES		# $t6 = the location in memory of the closest rabbit
	add $t6, $t6, 4	

	li $t0, 0			# $t0 = i
	j find_nearest_rabbit_loop

find_nearest_rabbit_loop:
	bge $t0, 15, get_info

	# find location of next bunny
	mul $t9, $t0, 16	# 16*i (each bunny has 16 bytes of data)
	add $t9, $t9, 4		# 16i+4 (offset for the number of bunnies)
	add $t9, $t9, $s7	# bunnies[i]
	lw $t3, 0($t9)		# $t3 = bunnies[i].x
	lw $t4, 4($t9)		# $t4 = bunnies[i].y
	
	# here is where I will find the Manhattan Distance
	sub $t3, $t3, $t1
	abs $t3, $t3
	sub $t4, $t4, $t2
	abs $t4, $t4
	move $t7, $t4
	
	# check if this duder is closer
	# if not, make this distance the smallest distance, and make this rabbit the new closest rabbit
	bgeu $t7, $t5, loop_end
	move $t5, $t7
	move $t6, $t9
	
	j loop_end

loop_end:
	add $t0, $t0, 1
	j find_nearest_rabbit_loop

get_info:
	# we now have the closest rabbit
	lw $t3, 0($t6)		# $t3 = bunnies[i].x
	lw $t4, 4($t6)		# $t4 = bunnies[i].y
	j move_x

move_x:
	# get position of bot
	lw $t1, BOT_X		#t3 = BOT_X

	# if (|bot.x - bunny.x| < 5)	// if the bunny is close enough in x
	#				// go to the y movement
	sub $t9, $t1, $t3		# $t9 = bot.x - bunny.x
	bge $t9, 4, move_x_left
	ble $t9, -4, move_x_right
	j move_y
	
move_x_left:
	# set the move direction to left
	li $t9, 180
	sw $t9, ANGLE
	li $t9, 1
	sw $t9, ANGLE_CONTROL
	li $t9, 10
	sw $t9, VELOCITY
	j move_x

move_x_right:
	li $t9, 0
	sw $t9, ANGLE
	li $t9, 1
	sw $t9, ANGLE_CONTROL
	li $t9, 10
	sw $t9, VELOCITY
	j move_x

move_y:
	# get position of bot
	lw $t2, BOT_Y			# $t4, BOT_Y
		
	sub $t9, $t2, $t4
	bge $t9, 4, move_y_up
	ble $t9, -4, move_y_down
	j give_carrot			# if we've reached this point, we must be within range of our rabbit

move_y_up:
	li $t9, 270
	sw $t9, ANGLE
	li $t9, 1
	sw $t9, ANGLE_CONTROL
	li $t9, 10
	sw $t9, VELOCITY
	j move_y

move_y_down:
	li $t9, 90
	sw $t9, ANGLE
	li $t9, 1
	sw $t9, ANGLE_CONTROL
	li $t9, 10
	sw $t9, VELOCITY
	j move_y

give_carrot:
	li $t9, 1
	sw $t9, CATCH_BUNNY
	lw $t9, 8($t6)			# bunnies[i].weight
	add $s0, $s0, $t9		# weight = weight+bunnies[i].weight
	add $s1, $s1, 1			# bunniesCaught++
	bge $s0, 100, playpen_x
	j find_nearest_rabbit_start

playpen_x:
	# get position of bot
	lw $t1, BOT_X		#t3 = BOT_X

	# if (|bot.x - bunny.x| < 5)	// if the bunny is close enough in x
	#				// go to the y movement
	sub $t9, $t1, $s2		# $t9 = bot.x - playpen.x
	bge $t9, 4, playpen_left
	ble $t9, -4, playpen_right
	j playpen_y

playpen_left:
	# set the move direction to left
	li $t9, 180
	sw $t9, ANGLE
	li $t9, 1
	sw $t9, ANGLE_CONTROL
	li $t9, 10
	sw $t9, VELOCITY
	j playpen_x

playpen_right:
	li $t9, 0
	sw $t9, ANGLE
	li $t9, 1
	sw $t9, ANGLE_CONTROL
	li $t9, 10
	sw $t9, VELOCITY
	j playpen_x

playpen_y:
	# get position of bot
	lw $t2, BOT_Y			# $t4, BOT_Y
		
	sub $t9, $t2, $s3		# $t9 = bot.y - playpen.y
	bge $t9, 4, playpen_up
	ble $t9, -4, playpen_down
	j dump			# if we've reached this point, we must be within range of our rabbit


playpen_up:
	li $t9, 270
	sw $t9, ANGLE
	li $t9, 1
	sw $t9, ANGLE_CONTROL
	li $t9, 10
	sw $t9, VELOCITY
	j playpen_y

playpen_down:
	li $t9, 90
	sw $t9, ANGLE
	li $t9, 1
	sw $t9, ANGLE_CONTROL
	li $t9, 10
	sw $t9, VELOCITY
	j playpen_y

dump:
	sw $s1, PUT_BUNNIES_IN_PLAYPEN	
	li $s0, 0			# zero weight untis
	li $s1, 0			# zero bunnies
	j find_nearest_rabbit_start

.kdata
chunkIH: .space 8
non_intrpt_str:	.asciiz "Non-interrupt exception\n"
unhandled_str:	.asciiz	"Unhandled interrupt type\n"

.ktext 0x80000180
interrupt_handler:
.set noat
	move $k1, $at			# set so we can't modify $at
.set at
	la $k0, chunkIH
	sw $a0, 0($k0)
	sw $a1, 4($k0)

	mfc0 $k0, $13			# get cause register
	srl $a0, $k0, 2
	and $a0, $a0, 0xf
	bne $a0, 0, non_intrpt

interrupt_dispatch:
	mfc0 $k0, $13
	beq $k0, $0, done
	
	and $a0, $k0, 0x1000		# check for bonk interrupt
	bne $a0, 0, bonk_interrupt

	and $a0, $k0, 0x8000		# check for timer interrupt
	bne $a0, 0, timer_interrupt

	and $a0, $k0, 0x400		# check for jump interrupt
	bne $a0, 0, jump_interrupt

	# add dispatch for other interrupt types here
	li $v0, 4
	la $a0, unhandled_str
	syscall
	j done

bonk_interrupt:
	sw $a1, BONK_ACK		# acknowledge
	sw $0, VELOCITY			# stop moving
	
	j interrupt_dispatch

timer_interrupt:
	sw $a1, TIMER_ACK		# acknowledge
	# literally do nothing, I don't understand why I would care

	j interrupt_dispatch

jump_interrupt:
	sw $a1, BUNNY_MOVE_ACK		# acknowledge
	# I was hoping to be able to find the new nearest rabit
	la $s7, bunnies_data
	sw $s7, SEARCH_BUNNIES

	la $a3, bunnies_data
	add $a3, 4
	lw $t3, 0($a3)
	lw $t4, 4($a3)

	j interrupt_dispatch

non_intrpt:
	li $v0, 4
	la $a0, non_intrpt_str
	syscall
	j done

done:
	la $k0, chunkIH
	lw $a0, 0($k0)
	lw $a1, 4($k0)
.set noat
	move $at, $k1
.set at
	eret

