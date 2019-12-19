	.globl 		_start
	.section	.text.startup
	.set        noreorder

.org 0x0
_start:
	# setup stack pointer
    la 		$sp, _stack
    la		$gp, _gp

	# jump to console entry
    jal 	_main
    nop