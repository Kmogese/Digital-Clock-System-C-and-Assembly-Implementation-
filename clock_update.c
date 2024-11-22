#include "clock.h"

extern int CLOCK_TIME_PORT;

int set_tod_from_ports(tod_t *tod) {
// Reads the time of day from the CLOCK_TIME_PORT global variable. If
// the port's value is invalid (negative or larger than 16 times the
// number of seconds in a day) does nothing to tod and returns 1 to
// indicate an error. Otherwise, this function uses the port value to
// calculate the number of seconds from start of day (port value is
// 16*number of seconds from midnight). Rounds seconds up if there at
// least 8/16 have passed. Uses shifts and masks for this calculation
// to be efficient. Then uses division on the seconds since the
// begining of the day to calculate the time of day broken into hours,
// minutes, seconds, and sets the AM/PM designation with 1 for AM and
// 2 for PM. By the end, all fields of the `tod` struct are filled in
// and 0 is returned for success.
// 
// CONSTRAINT: Uses only integer operations. No floating point
// operations are used as the target machine does not have a FPU.
// 
// CONSTRAINT: Limit the complexity of code as much as possible. Do
// not use deeply nested conditional structures. Seek to make the code
// as short, and simple as possible. Code longer than 40 lines may be
// penalized for complexity.

const int SECONDS_IN_DAY = 86400;  // 24 * 60 * 60
const int SECONDS_IN_HOUR = 3600;
const int SECONDS_IN_MINUTE = 60;

// Check for valid clock value
if (CLOCK_TIME_PORT < 0 || CLOCK_TIME_PORT >= SECONDS_IN_DAY * 16) {
    return 1;  
}

int total_seconds = (CLOCK_TIME_PORT + 8) >> 4;

tod->day_secs = total_seconds;

int hours = total_seconds / SECONDS_IN_HOUR;
int remaining_seconds = total_seconds % SECONDS_IN_HOUR;
int minutes = remaining_seconds / SECONDS_IN_MINUTE;
int seconds = remaining_seconds % SECONDS_IN_MINUTE;


tod->time_hours = hours % 12;
if (tod->time_hours == 0) tod->time_hours = 12;  // 12-hour format

tod->ampm = (hours >= 12) ? 2 : 1;  // 1 for AM, 2 for PM

tod->time_mins = minutes;
tod->time_secs = seconds;

return 0;  
}


int set_display_from_tod(tod_t tod, int *display) {
// Accepts a tod and alters the bits in the int pointed at by display
// to reflect how the LCD clock should appear. If any time_** fields
// of tod are negative or too large (e.g. bigger than 12 for hours,
// bigger than 59 for min/sec) or if the AM/PM is not 1 or 2, no
// change is made to display and 1 is returned to indicate an
// error. The display pattern is constructed via shifting bit patterns
// representing digits and using logical operations to combine them.
// May make use of an array of bit masks corresponding to the pattern
// for each digit of the clock to make the task easier.  Returns 0 to
// indicate success. This function DOES NOT modify any global
// variables
// 
// CONSTRAINT: Limit the complexity of code as much as possible. Do
// not use deeply nested conditional structures. Seek to make the code
// as short, and simple as possible. Code longer than 85 lines may be
// penalized for complexity.

// Check if the time fields are valid
if (tod.time_hours < 1 || tod.time_hours > 12 || 
    tod.time_mins < 0 || tod.time_mins >= 60 || 
    tod.ampm < 1 || tod.ampm > 2) {
    return 1;  
}

const int digit_masks[10] = {
    0b1110111,  // 0
    0b0100100,  // 1
    0b1011101,  // 2
    0b1101101,  // 3
    0b0101110,  // 4
    0b1101011,  // 5
    0b1111011,  // 6
    0b0100101,  // 7
    0b1111111,  // 8
    0b1101111   // 9
};

*display = 0;  // Clear the display

// Extract digits for hours and minutes
int hour_tens = tod.time_hours / 10;
int hour_ones = tod.time_hours % 10;
int min_tens = tod.time_mins / 10;
int min_ones = tod.time_mins % 10;

*display |= digit_masks[min_ones];

*display |= digit_masks[min_tens] << 7;

*display |= digit_masks[hour_ones] << 14;

if (hour_tens > 0) {
    *display |= digit_masks[hour_tens] << 21;
}

if (tod.ampm == 1) {
    *display |= (1 << 28);  // AM
} else {
    *display |= (1 << 29);  // PM
}

return 0;  
}
extern int CLOCK_DISPLAY_PORT;

int clock_update() {
// Examines the CLOCK_TIME_PORT global variable to determine hour,
// minute, and am/pm.  Sets the global variable CLOCK_DISPLAY_PORT bits
// to show the proper time.  If CLOCK_TIME_PORT appears to be in error
// (to large/small) makes no change to CLOCK_DISPLAY_PORT and returns 1
// to indicate an error. Otherwise returns 0 to indicate success.
//
// Makes use of the previous two functions: set_tod_from_ports() and
// set_display_from_tod().
// 
// CONSTRAINT: Does not allocate any heap memory as malloc() is NOT
// available on the target microcontroller.  Uses stack and global
// memory only.
tod_t current_time;
int result = set_tod_from_ports(&current_time);

if (result == 1) {
    return 1;  
}

int display = 0;
result = set_display_from_tod(current_time, &display);

if (result == 1) {
    return 1;  
}

CLOCK_DISPLAY_PORT = display;  // Update the display port

return 0;  
}

