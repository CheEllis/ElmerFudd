# syscall constants
PRINT_STRING = 4
PRINT_CHAR   = 11
PRINT_INT    = 1

# debug constants
PRINT_INT_ADDR   = 0xffff0080
PRINT_FLOAT_ADDR = 0xffff0084
PRINT_HEX_ADDR   = 0xffff0088

# spimbot constants
VELOCITY       = 0xffff0010
ANGLE          = 0xffff0014
ANGLE_CONTROL  = 0xffff0018
BOT_X          = 0xffff0020
BOT_Y          = 0xffff0024
OTHER_BOT_X    = 0xffff00a0
OTHER_BOT_Y    = 0xffff00a4
TIMER          = 0xffff001c
SCORES_REQUEST = 0xffff1018

# introduced in lab10
SEARCH_BUNNIES          = 0xffff0054
CATCH_BUNNY             = 0xffff0058
PUT_BUNNIES_IN_PLAYPEN  = 0xffff005c
PLAYPEN_LOCATION        = 0xffff0044

# introduced in labSpimbot
LOCK_PLAYPEN            = 0xffff0048
UNLOCK_PLAYPEN          = 0xffff004c
REQUEST_PUZZLE          = 0xffff00d0
SUBMIT_SOLUTION         = 0xffff00d4
NUM_BUNNIES_CARRIED     = 0xffff0050
NUM_CARROTS             = 0xffff0040
PLAYPEN_OTHER_LOCATION  = 0xffff00dc

# interrupt constants
BONK_MASK               = 0x1000
BONK_ACK                = 0xffff0060
TIMER_MASK              = 0x8000

TIMER_ACK               = 0xffff006c
BUNNY_MOVE_INT_MASK     = 0x400
BUNNY_MOVE_ACK          = 0xffff0020
PLAYPEN_UNLOCK_INT_MASK = 0x2000
PLAYPEN_UNLOCK_ACK      = 0xffff005c
EX_CARRY_LIMIT_INT_MASK = 0x4000
EX_CARRY_LIMIT_ACK      = 0xffff002c
REQUEST_PUZZLE_INT_MASK = 0x800
REQUEST_PUZZLE_ACK      = 0xffff00d8

# Boolean Masks
# use $t9 for Bit Flags
CAN_OPEN_ENEMY_PLAYPEN	= 0x00000001	# flag for if the enemy's playpen can be opened
PUZZLE_READY		= 0x00000002	# flag for if the puzzle is ready
PUZZLE_REQUESTED	= 0x00000004	# we requested the puzzle, there's no need to request another one
HAS_ENEMY		= 0xf0000000	# true if we have an opponent in this simulation

.data
turns: .word 1 0 -1 0

.align 2
bunnies_data: .space 484
puzzle_data: .space 9804
baskets_data: .space 44
integer_solution: .space 4

##### REGISTER VARIABLE INDEX #####
##### T Registers
# $t0 - register for temporary values, i.e. holds values used in branch condition testing
# $t9 - holds bit flags used for bot's decision making
##### S Registers
# $



 .text
 main:
	##### Initialization Stuff #####
	# enable interrupts
        li      $t4, TIMER_MASK                 	# timer interrupt enable bit
        or      $t4, $t4, BONK_MASK             	# bonk interrupt bit
        or      $t4, $t4, BUNNY_MOVE_INT_MASK   	# jump interrupt bit
	or	$t4, $t4, REQUEST_PUZZLE_INT_MASK	# puzzle interrupt bit
	or	$t4, $t4, EX_CARRY_LIMIT_INT_MASK	# weight interrupt bit
        or      $t4, $t4, 1				# global interrupt enable
        mtc0    $t4, $12				# set interrupt mask (Status register)

	# set flag if we have an enemy
	# reading from any of the enemy bot queries will return -1
	lw $t0, OTHER_BOT_X
	beq $t0, -1, enemy_bot_false	# if the return value is negative 1, skip setting the flag
	or $t9, $t9, HAS_ENEMY

enemy_bot_false:
	j start

start:
	# branch to request puzzle
	and $t0, $t9, PUZZLE_REQUESTED
	bgt $t0, $0, no_request
	la $t0, puzzle_data
	sw $t0, REQUEST_PUZZLE
	or $t9, $t9, PUZZLE_REQUESTED
	
no_request:
	# branch to do puzzle
	and $t0, $t9, PUZZLE_READY
	bne $t0, $0, puzzle_init

	# @TODO find and catch bunnies
	# return bunnies to pen
	# lock our own pen
	# unlock enemy pen
	# consider all logic that goes with it
	# us
	
	j start

puzzle_init:
	# initialize values for search carrot
	# search_carrot(int max_baskets, int k, Node* root, Baskets* baskets)
	sw $0, VELOCITY	# stop the bot for now
	la $t9, PUZZLE_READY
	not $t9, $t9
	and $t9, $t0, $t9

	la $t0, puzzle_data
	li $a0, 10		# max baskets should always be 10
				# @OPT set this value up in the initialization stage and never touch it again
	lw $a1, 9800($t0)	# k is the last word in the puzzle struct
	la $a2, puzzle_data	# root node (?)

	la $a3, baskets_data
	sw $0, baskets_data
	
	jal search_carrot
	sw $v0, integer_solution
	la $v0, integer_solution
	sw $v0, SUBMIT_SOLUTION
	#turn off puzzle ready flag
	la $t0, PUZZLE_READY
	not $t0, $t0
	and $t9, $t9, $t0
	# turn off requested puzzle flag
	la $t0, PUZZLE_REQUESTED
	not $t0, $t0
	and $t9, $t9, $t0
	

	j start
	
	
##### PROVIDED PUZZLE SOLVER CODE #####	

search_carrot:
	move	$v0, $0			# set return value to 0 early
	beq	$a2, 0, sc_ret		# if (root == NULL), return 0
	beq	$a3, 0, sc_ret		# if (baskets == NULL), return 0

	sub	$sp, $sp, 12
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)

	move	$s0, $a1		# $s0 = int k
	move	$s1, $a3		# $s1 = Baskets *baskets

	sw	$0, 0($a3)		# baskets->num_found = 0

	move	$t0, $0			# $t0 = int i = 0
sc_for:
	bge	$t0, $a0, sc_done	# if (i >= max_baskets), done

	mul	$t1, $t0, 4
	add	$t1, $t1, $a3
	sw	$t0, 4($t1)		# baskets->basket[i] = NULL

	add	$t0, $t0, 1		# i++
	j	sc_for


sc_done:
	move	$a1, $a2
	move	$a2, $a3
	jal	collect_baskets		# collect_baskets(max_baskets, root, baskets)

	move	$a0, $s0
	move	$a1, $s1
	jal	pick_best_k_baskets	# pick_best_k_baskets(k, baskets)

	move	$a0, $s0
	move	$a1, $s1

	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	add	$sp, $sp, 12

	j	get_secret_id		# get_secret_id(k, baskets), tail call

sc_ret:
	jr	$ra

pick_best_k_baskets:
	bne	$a1, 0, pbkb_do
	jr	$ra

pbkb_do:
	sub	$sp, $sp, 32
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	sw	$s5, 24($sp)
	sw	$s6, 28($sp)

	move	$s0, $a0			# $s0 = int k
	move	$s1, $a1			# $s1 = Baskets *baskets

	li	$s2, 0				# $s2 = int i = 0
pbkb_for_i:
	bge	$s2, $s0, pbkb_done		# if (i >= k), done

	lw	$s3, 0($s1)
	sub	$s3, $s3, 1			# $s3 = int j = baskets->num_found - 1
pbkb_for_j:
	ble	$s3, $s2, pbkb_for_j_done	# if (j <= i), done

	sub	$s5, $s3, 1
	mul	$s5, $s5, 4
	add	$s5, $s5, $s1
	lw	$a0, 4($s5)			# baskets->basket[j-1]
	jal	get_num_carrots			# get_num_carrots(baskets->basket[j-1])
	move	$s4, $v0

	mul	$s6, $s3, 4
	add	$s6, $s6, $s1
	lw	$a0, 4($s6)			# baskets->basket[j]
	jal	get_num_carrots			# get_num_carrots(baskets->basket[j])

	bge	$s4, $v0, pbkb_for_j_cont	# if (get_num_carrots(baskets->basket[j-1]) >= get_num_carrots(baskets->basket[j])), skip

	## This is very inefficient in MIPS. Can you think of a better way?

	## We're changing the _values_ of the array elements, so we don't need to
	## recompute addresses every time, and can reuse them from earlier.

	lw	$t0, 4($s6)			# baskets->basket[j]
	lw	$t1, 4($s5)			# baskets->basket[j-1]
	xor	$t2, $t0, $t1			# baskets->basket[j] ^ baskets->basket[j-1]
	sw	$t2, 4($s6)			# baskets->basket[j] = baskets->basket[j] ^ baskets->basket[j-1]

	lw	$t0, 4($s6)			# baskets->basket[j]
	lw	$t1, 4($s5)			# baskets->basket[j-1]
	xor	$t2, $t0, $t1			# baskets->basket[j] ^ baskets->basket[j-1]
	sw	$t2, 4($s5)			# baskets->basket[j-1] = baskets->basket[j] ^ baskets->basket[j-1]

	lw	$t0, 4($s6)			# baskets->basket[j]
	lw	$t1, 4($s5)			# baskets->basket[j-1]
	xor	$t2, $t0, $t1			# baskets->basket[j] ^ baskets->basket[j-1]
	sw	$t2, 4($s6)			# baskets->basket[j] = baskets->basket[j] ^ baskets->basket[j-1]

pbkb_for_j_cont:
	sub	$s3, $s3, 1			# j--
	j	pbkb_for_j

pbkb_for_j_done:
	add	$s2, $s2, 1			# i++
	j	pbkb_for_i

pbkb_done:
	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	lw	$s5, 24($sp)
	lw	$s6, 28($sp)
	add	$sp, $sp, 32
	jr	$ra

get_secret_id:
	bne	$a1, 0, gsi_do		# if (baskets != NULL), continue
	move	$v0, $0			# return 0
	jr	$ra

gsi_do:
	sub	$sp, $sp, 20
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)

	move	$s0, $a0		# $s0 = int k
	move	$s1, $a1		# $s1 = Baskets *baskets
	move	$s2, $0			# $s2 = int secret_id = 0

	move	$s3, $0			# $s3 = int i = 0
gsi_for:
	bge	$s3, $s0, gsi_return	# if (i >= k), done

	mul	$t0, $s3, 4
	add	$t0, $t0, $s1
	lw	$t0, 4($t0)		# baskets->basket[i]

	lw	$a0, 16($t0)		# baskets->basket[i]->identity
	lw	$a1, 12($t0)		# baskets->basket[i]->id_size
	jal	calculate_identity	# calculate_identity(baskets->basket[i]->identity, baskets->basket[i]->id_size)

	addu	$s2, $s2, $v0		# secret_it += ...

	add	$s3, $s3, 1		# i++
	j	gsi_for

gsi_return:
	move	$v0, $s2		# return secret_id

	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	add	$sp, $sp, 20
	jr	$ra

get_num_carrots:
	bne	$a0, 0, gnc_do		# if (spot != NULL), continue
	move	$v0, $0			# return 0
	jr	$ra

gnc_do:
	lw	$t0, 8($a0)		# spot->dirt
	xor	$t0, $t0, 0x00ff00ff	# $t0 = unsigned int dig = spot->dirt ^ 0x00ff00ff

	and	$t1, $t0, 0xffffff 	# dig & 0xffffff
	sll	$t1, $t1, 8		# (dig & 0xffffff) << 8

	and	$t2, $t0, 0xff000000 	# dig & 0xff00aadi0000
	srl	$t2, $t2, 24		# (dig & 0xff000000) >> 24

	or	$t0, $t1, $t2		# dig = ((dig & 0xffffff) << 8) | ((dig & 0xff000000) >> 24)

	lw	$v0, 4($a0)		# spot->basket
	xor	$v0, $v0, $t0		# return spot->basket ^ dig
	jr	$ra

collect_baskets:
	beq	$a1, 0, cb_ret		# if (spot == NULL), return
	beq	$a2, 0, cb_ret		# if (baskets == NULL), return
	lb	$t0, 0($a1)
	beq	$t0, 1, cb_ret		# if (spot->seen == 1), return

	li	$t0, 1
	sb	$t0, 0($a1)		# spot->seen = 1

	sub	$sp, $sp, 20
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)

	move	$s0, $a0		# $s0 = int max_baskets
	move	$s1, $a1		# $s1 = Node *spot
	move	$s2, $a2		# $s2 = Baskets *baskets

	move	$s3, $0			# $s3 = int i = 0
cb_for:
	lw	$t0, 20($s1)		# spot->num_children
	bge	$s3, $t0, cb_done	# if (i >= spot->num_children), done
	lw	$t0, 0($s2)		# baskets->num_found
	bge	$t0, $s0, cb_done	# if (baskets->num_found >= max_baskets), done

	move	$a0, $s0
	mul	$a1, $s3, 4
	add	$a1, $a1, $s1
	lw	$a1, 24($a1)		# spot->children[i]
	move	$a2, $s2
	jal	collect_baskets		# collect_baskets(max_baskets, spot->children[i], baskets)

	add	$s3, $s3, 1		# i++
	j	cb_for


cb_done:
	lw	$t0, 0($s2)		# baskets->num_found
	bge	$t0, $s0, cb_return	# if (baskets->num_found >= max_baskets), return

	move	$a0, $s1
	jal	get_num_carrots
	ble	$v0, 0, cb_return 	# if (get_num_carrots(spot) <= 0), return

	lw	$t0, 0($s2)		# baskets->num_found
	mul	$t1, $t0, 4
	add	$t1, $t1, $s2
	sw	$s1, 4($t1)		# baskets->basket[baskets->num_found] = spot

	add	$t0, $t0, 1
	sw	$t0, 0($s2)		# baskets->num_found++

cb_return:
	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	add	$sp, $sp, 20

cb_ret:
	jr	$ra
	mul	$t0, $s3, 4

calculate_identity:
	sub	$sp, $sp, 36
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	sw	$s5, 24($sp)
	sw	$s6, 28($sp)
	sw	$s7, 32($sp)

	move	$s0, $a0		# $s0 = int *v
	move	$s1, $a1		# $s1 = int size

	move	$s2, $s1		# $s2 = int dist = size
	move	$s3, $0			# $s3 = int total = 0
	li	$s4, -1			# $s4 = int idx = -1

	sw	$s1, turns+4		# turns[1] = size
	mul	$t0, $s1, $s4		# -size
	sw	$t0, turns+12		# turns[3] = -size

ci_while:
	ble	$s2, 0, ci_done		# if (dist <= 0), done

	li	$s5, 0			# $s5 = int i = 0
ci_for_i:
	bge	$s5, 4, ci_while 	# if (i >= 4), done

	li	$s6, 0			# $s6 = int j = 0
ci_for_j:
	bge	$s6, $s2, ci_for_j_done # if (j >= dist), dine

	la	$t1, turns
	mul	$t0, $s5, 4
	add	$t0, $t0, $t1		# &turns[i]
	lw	$t0, 0($t0)		# turns[i]
	add	$s4, $s4, $t0		# idx = idx + turns[i]

	move	$a0, $s3		# total

	mul	$s7, $s4, 4
	add	$s7, $s7, $s0		# &v[idx]
	lw	$a1, 0($s7)		# v[idx]

	jal	accumulate		# accumulate(total, v[idx])
	move	$s3, $v0		# total = accumulate(total, v[idx])
	sw	$s3, 0($s7)		# v[idx] = total

	add	$s6, $s6, 1		# j++
	j	ci_for_j

ci_for_j_done:
	rem	$t0, $s5, 2		# i % 2
	bne	$t0, 0, ci_skip		# if (i % 2 != 0), skip
	sub	$s2, $s2, 1		# dist--

ci_skip:
	add	$s5, $s5, 1		# i++
	j	ci_for_i

ci_done:
	move	$a0, $s0		# v
	mul	$a1, $s1, $s1		# size * size
	jal	twisted_sum_array	# twisted_sum_array(v, size * size)

	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	lw	$s5, 24($sp)
	lw	$s6, 28($sp)
	lw	$s7, 32($sp)
	add	$sp, $sp, 36
	jr	$ra

detect_parity:
	li	$t1, 0			# $t1 = int bits_counted = 0
	li	$v0, 1			# $v0 = int return_value = 1

	li	$t0, 0			# $t0 = int i = 0
dp_for:
	bge	$t0, 32, dp_done	# if (i >= INT_SIZE), done

	sra	$t3, $a0, $t0		# number >> i
	and	$t3, $t3, 1		# $t3 = int bit = (number >> i) & 1

	beq	$t3, 0, dp_skip		# if (bit == 0), skip
	add	$t1, $t1, 1		# bits_counted++

dp_skip:
	add	$t0, $t0, 1		# i++
	j	dp_for

dp_done:
	rem	$t3, $t1, 2		# bits_counted % 2
	beq	$t3, 0, dp_ret		# if (bits_counted % 2 == 0), skip
	li	$v0, 0			# return_value = 0

dp_ret:
	jr	$ra			# $v0 is already return_value

accumulate:
	sub	$sp, $sp, 12
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)

	move	$s0, $a0
	move	$s1, $a1

	jal	max_conts_bits_in_common
	blt	$v0, 2, a_dp
	or	$v0, $s0, $s1
	j	a_ret

a_dp:
	move	$a0, $s1
	jal	detect_parity
	bne	$v0, 0, a_mul
	addu	$v0, $s0, $s1
	j	a_ret

a_mul:
	mul	$v0, $s0, $s1

a_ret:
	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	add	$sp, $sp, 12
	jr	$ra

max_conts_bits_in_common:
	li	$t1, 0			# $t1 = int bits_seen = 0
	li	$v0, 0			# $v0 = int max_seen = 0
	and	$t2, $a0, $a1		# $t2 = int c = a & b

	li	$t0, 0			# $t0 = int i = 0
mcbic_for:
	bge	$t0, 32, mcbic_done	# if (i >= INT_SIZE), done

	sra	$t3, $t2, $t0		# c >> i
	and	$t3, $t3, 1		# $t3 = int bit = (c >> i) & 1

	beq	$t3, 0, mcbic_else 	# if (bit == 0), else
	add	$t1, $t1, 1		# bits_seen++
	j	mcbic_cont

mcbic_else:
	ble	$t1, $v0, mcbic_skip 	# if (bit_seen <= max_seen), skip
	move	$v0, $t1		# max_seen = bits_seen

mcbic_skip:
	li	$t1, 0			# bits_seen = 0

mcbic_cont:
	add	$t0, $t0, 1		# i++
	j	mcbic_for

mcbic_done:
	ble	$t1, $v0, mcbic_ret 	# if (bits_seen <= max_seen), skip
	move	$v0, $t1		# max_seen = bits_seen

mcbic_ret:
	jr	$ra			# $v0 is already max_seen

twisted_sum_array:
	li	$v0, 0			# $v0 = int sum = 0

	li	$t0, 0			# $t0 = int i = 0
tsa_for:
	bge	$t0, $a1, tsa_done	# if (i >= length), done

	sub	$t1, $a1, 1		# length - 1
	sub	$t1, $t1, $t0		# length - 1 - i
	mul	$t1, $t1, 4
	add	$t1, $t1, $a0		# &v[length - 1 - i]
	lw	$t2, 0($t1)		# v[length - 1 - i]
	and	$t2, $t2, 1		# v[length - 1 - i] & 1

	beq	$t2, 0, tsa_skip	# if (v[length - 1 - i] & 1 == 0), skip
	sra	$v0, $v0, 1		# sum >>= 1

tsa_skip:
	mul	$t1, $t0, 4
	add	$t1, $t1, $a0		# &v[i]
	lw	$t2, 0($t1)		# v[i]
	addu	$v0, $v0, $t2		# sum += v[i]

	add	$t0, $t0, 1		# i++
	j	tsa_for

tsa_done:
	jr	$ra			# $v0 is already sum

##### INTERRUPT HANDLER #####

.kdata
chunkIH: .space 8
non_intrpt_str: .asciiz "Non-interrupt exception\n"
unhandled_str:  .asciiz "Unhandled interrupt type\n"

.ktext 0x80000180
interrupt_handler:
.set noat
        move $k1, $at                   # set so we can't modify $at
.set at
	# save s registers, restore before returning to main loops
        la $k0, chunkIH
        sw $s0, 0($k0)
        sw $s1, 4($k0)
	sw $s2, 8($k0)
	sw $s3, 12($k0)
	sw $s4, 16($k0)

        mfc0 $k0, $13                   # get cause register
        srl $s0, $k0, 2
        and $s0, $s0, 0xf
        bne $s0, 0, non_intrpt

interrupt_dispatch:
        mfc0 $k0, $13
        beq $k0, $0, done

        and $s0, $k0, 0x1000            # check for bonk interrupt
        bne $s0, 0, bonk_interrupt

        and $s0, $k0, 0x8000            # check for timer interrupt
        bne $s0, 0, timer_interrupt

        and $s0, $k0, 0x400             # check for jump interrupt
        bne $s0, 0, jump_interrupt

	and $s0, $k0, REQUEST_PUZZLE_INT_MASK
	bne $s0, 0, puzzle_interrupt

        # add dispatch for other interrupt types here
        li $v0, 4
        la $s0, unhandled_str
        syscall
        j done

puzzle_interrupt:
	# throws this interrupt when the puzzle has been generated and we can start working on it
	sw $s1, REQUEST_PUZZLE_ACK	# acknowledge
	or $t9, $t9, PUZZLE_READY	# bit flag tells us that the puzzle is ready
	
	j interrupt_dispatch

bonk_interrupt:
        sw $s1, BONK_ACK                # acknowledge
	li $t0, 180
	sw $t0, ANGLE
	li $t0, 0
	sw $t0, ANGLE_CONTROL
        #sw $t0, VELOCITY                 # stop moving

        j interrupt_dispatch

timer_interrupt:
        sw $s1, TIMER_ACK               # acknowledge
        # @TODO see if I can set up a timer interrupt for when the enemy locks their gate

        j interrupt_dispatch

jump_interrupt:
        sw $s1, BUNNY_MOVE_ACK                # acknowledge
	# currently, this just finds the first bunny in the array
	# and sets its coordinates to be the target location
	# @TODO

        #la $s4, bunnies_data
        #sw $s4, SEARCH_BUNNIES
        #la $s2, bunnies_data
        #add $s2, 4
        #lw $t3, 0($s2)
        #lw $t4, 4($s2)

        j interrupt_dispatch

non_intrpt:
        li $v0, 4
        la $s0, non_intrpt_str
        syscall
        j done

done:
	# restore saved registers after handling exceptions
	# try to use as few saved registers as possible, try to
	# minimize loads necessary for s register restoration
        la $k0, chunkIH
        lw $s0, 0($k0)
        lw $s1, 4($k0)
	lw $s2, 8($k0)
	lw $s3, 12($k0)
	lw $s4, 16($k0)	

.set noat
        move $at, $k1
.set at
        eret

