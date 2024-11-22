.text                           # IMPORTANT: subsequent stuff is executable
.global set_tod_from_ports


## ENTRY POINT FOR REQUIRED FUNCTION
set_tod_from_ports:
    # Load CLOCK_TIME_PORT into %eax
    movl    CLOCK_TIME_PORT(%rip), %eax    # %eax = CLOCK_TIME_PORT

    # Check if CLOCK_TIME_PORT < 0
    cmpl    $0, %eax                       # Compare %eax with 0
    jl      set_tod_from_ports_error_return   # If less than 0, jump to error_return

    # Check if CLOCK_TIME_PORT >= SECONDS_IN_DAY * 16 (1382400)
    cmpl    $1382400, %eax                 # Compare %eax with 1382400
    jge     set_tod_from_ports_error_return   # If >=, jump to error_return

    # Compute total_seconds = (CLOCK_TIME_PORT + 8) >> 4
    addl    $8, %eax                       # %eax = CLOCK_TIME_PORT + 8
    sarl    $4, %eax                       # Shift right by 4 bits: %eax = total_seconds

    # Save total_seconds for later use
    movl    %eax, %r8d                     # %r8d = total_seconds

    # Store total_seconds into tod->day_secs
    movl    %eax, 0(%rdi)                  # tod->day_secs = total_seconds

    # Compute hours = total_seconds / 3600
    # Prepare for division
    movl    %r8d, %eax                     # %eax = total_seconds
    movl    $3600, %ecx                    # %ecx = 3600 (seconds)
    cdq                                    # Sign-extend %eax into %edx
    idivl   %ecx                           # eax = eax / ecx; edx = eax % ecx
    # Now, %eax = hours, %edx = remaining_seconds

    # Save hours and remaining_seconds
    movl    %eax, %r9d                     # %r9d = hours
    movl    %edx, %r10d                    # %r10d = remaining_seconds

    # Compute minutes = remaining_seconds / 60
    # Prepare for division
    movl    %r10d, %eax                    # %eax = remaining_seconds
    movl    $60, %ecx                      # %ecx = 60 (SECONDS_IN_MINUTE)
    cdq                                    # Sign-extend %eax into %edx
    idivl   %ecx                           # eax = eax / ecx; edx = eax % ecx
    # Now, %eax = minutes, %edx = seconds

    # Save minutes and seconds
    movl    %eax, %r11d                    # %r11d = minutes
    movl    %edx, %r12d                    # %r12d = seconds

    # Compute time_hours = hours % 12
    movl    %r9d, %eax                     # %eax = hours
    movl    $12, %ecx                      # %ecx = 12
    cdq                                    # Sign-extend %eax into %edx
    idivl   %ecx                           # Divide to get quotient and remainder
    # Now, %edx = time_hours (hours % 12)

    # Handle 12-hour format
    testl   %edx, %edx                     # Check if time_hours == 0
    jne     time_hours_not_zero            # If not zero, skip setting to 12
    movl    $12, %edx                      # time_hours = 12
time_hours_not_zero:
    # Store time_hours into tod->time_hours
    movw    %dx, 8(%rdi)                   # tod->time_hours = time_hours

    # Determine AM or PM
    cmpl    $12, %r9d                      # Compare hours with 12
    jl      set_am                         # If hours < 12, it's AM
    # hours >= 12
    movb    $2, 10(%rdi)                   # tod->ampm = 2 (PM)
    jmp     store_minutes_seconds          # Skip setting AM
set_am:
    movb    $1, 10(%rdi)                   # tod->ampm = 1 (AM)

store_minutes_seconds:
    # Store minutes and seconds into tod_t
    movw    %r11w, 6(%rdi)                 # tod->time_mins = minutes
    movw    %r12w, 4(%rdi)                 # tod->time_secs = seconds

    # Function succeeded
    movl    $0, %eax                       # Return 0
    ret                                    # Return from function

set_tod_from_ports_error_return:
    # Function failed
    movl    $1, %eax                       # Return 1
    ret                                    # Return from function


.text
.global set_display_from_tod

## ENTRY POINT FOR REQUIRED FUNCTION
set_display_from_tod:
    # Preserve callee-saved regs
    pushq   %rbx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15

    # Check if display pointer is null
    testq   %rdx, %rdx
    jz      .Lerror

    # Extract fields first
    movq    %rdi, %r12        # Save rdi
    movq    %rsi, %r13        # Save rsi
    movq    %rdx, %r14        # Save display pointer

    # Extract time_hours (lower 16 bits of rsi)
    movzwl  %si, %ebx
    
    # Extract time_mins (bits 48-63 of rdi)
    movq    %rdi, %rax
    shrq    $48, %rax
    movzwl  %ax, %r15d

    # Extract ampm (bits 16-23 of rsi)
    movq    %rsi, %rax
    shrq    $16, %rax
    movzbl  %al, %r12d

    # Validate all fields before modifying display
    # Validate time_hours (1-12)
    cmpl    $1, %ebx
    jl      .Lerror
    cmpl    $12, %ebx
    jg      .Lerror

    # Validate time_mins (0-59)
    cmpl    $0, %r15d
    jl      .Lerror
    cmpl    $60, %r15d
    jge     .Lerror

    # Validate ampm (1-2)
    cmpl    $1, %r12d
    jl      .Lerror
    cmpl    $2, %r12d
    jg      .Lerror

    # If validation passed-
    movl    $0, (%r14)        # Clear display only after validation

    # Get digits for hours
    movl    %ebx, %eax        # time_hours
    movl    $10, %ecx
    xorl    %edx, %edx
    divl    %ecx              # time_hours / 10
    movl    %eax, %r13d       # hour_tens
    movl    %edx, %ebx        # hour_ones

    # Get digits for minutes
    movl    %r15d, %eax       # time_mins
    xorl    %edx, %edx
    divl    %ecx              # time_mins / 10
    movl    %eax, %r15d       # min_tens
    movl    %edx, %r8d        # min_ones

    # Load digit_masks address
    leaq    digit_masks(%rip), %rcx

    # Build display - min_ones
    movslq  %r8d, %rax        
    movl    (%rcx,%rax,4), %eax
    orl     %eax, (%r14)

    # Add min_tens
    movslq  %r15d, %rax
    movl    (%rcx,%rax,4), %eax
    shll    $7, %eax
    orl     %eax, (%r14)

    # Add hour_ones
    movslq  %ebx, %rax
    movl    (%rcx,%rax,4), %eax
    shll    $14, %eax
    orl     %eax, (%r14)

    # Add hour_tens if non-zero
    testl   %r13d, %r13d
    jz      .Lskip_hour_tens
    movslq  %r13d, %rax
    movl    (%rcx,%rax,4), %eax
    shll    $21, %eax
    orl     %eax, (%r14)
.Lskip_hour_tens:

    # Set AM/PM bit
    cmpl    $1, %r12d         # Compare ampm with 1
    jne     .Lset_pm
    movl    $1, %eax
    shll    $28, %eax         # AM bit
    jmp     .Lset_ampm
.Lset_pm:
    movl    $1, %eax
    shll    $29, %eax         # PM bit
.Lset_ampm:
    orl     %eax, (%r14)

    xorl    %eax, %eax        # Return 0 for success
    jmp     .Lexit

.Lerror:
    movl    $1, %eax          # Return 1 for error

.Lexit:
    # Restore callee-saved registers
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rbx
    ret

.data
digit_masks:
    .int 0b1110111    # 0
    .int 0b0100100    # 1
    .int 0b1011101    # 2
    .int 0b1101101    # 3
    .int 0b0101110    # 4
    .int 0b1101011    # 5
    .int 0b1111011    # 6
    .int 0b0100101    # 7
    .int 0b1111111    # 8
    .int 0b1101111    # 9

  
.text
.global clock_update
## ENTRY POINT FOR REQUIRED FUNCTION
clock_update:
    pushq   %rbp                # Save base pointer
    movq    %rsp, %rbp          # Set base pointer

    # Save callee-saved registers
    pushq   %rbx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15

    #stack alignment to 16 bytes before function calls
    subq    $32, %rsp           # Allocate space

    # Prepare arguments and call set_tod_from_ports
    leaq    16(%rsp), %rdi     # Address of tod_t on the stack
    call    set_tod_from_ports

    # Check return value
    cmp     $0, %eax
    jne     clock_update_error_return

    # Prepare arguments and call set_display_from_tod
    movq    16(%rsp), %rdi     # First part of tod_t
    movq    24(%rsp), %rsi     # Second part of tod_t
    leaq    12(%rsp), %rdx     # Address of display integer
    call    set_display_from_tod

    # Check return value
    cmp     $0, %eax
    jne     clock_update_error_return

    # Update CLOCK_DISPLAY_PORT
    movl    12(%rsp), %eax     # Load display integer
    movl    %eax, CLOCK_DISPLAY_PORT(%rip)

    # Clean up and return success
    movl    $0, %eax            # Return value 0 
    jmp     clock_update_exit

clock_update_error_return:
    movl    $1, %eax            # Return value 1 

clock_update_exit:
    addq    $32, %rsp           # Deallocate space

    # Restore callee-saved registers
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rbx

    movq    %rbp, %rsp          # Restore stack pointer
    popq    %rbp                # Restore base pointer
    ret
