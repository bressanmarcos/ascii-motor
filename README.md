# ascii-motor
Project for the Microcontrollers and Microprocessors course.

This project is a challenge proposed by the professors of the course. The requirements are:
- Two PIC16F628 microcontrollers must be present and communicate between themselves using serial communication.
- A 7-segment display and a step motor must output the sequence of bytes received, one nibble at a time.
- The first µC should be programmed to send a pre-defined list of bytes corresponding to an ASCII-encoded string.
- The second µC should receive each byte and split it up into its two nibbles. For each nibble, this µC should:
  - Show the corresponding hexadecimal value for the nibble in the 7-segment display. The first nibble is represented by the 'dot' LED on in the display;
  - Move the step motor to achieve the circular sector corresponding to this hexadecimal value.
- The step motor position indicates the current nibble in a circle containing 16 ciruclar sectors of same size, which represent hexadecimals from 0 to F.
