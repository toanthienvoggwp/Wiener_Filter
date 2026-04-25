# Wiener Filter - MIPS Assembly

**Project:** CA_Assignment_251  
**Language:** MIPS Assembly  
**Recommended Runtime Environment:** MARS (MIPS Assembler and Runtime Simulator)

---

## 1. Introduction
This project is an implementation of the **Wiener Filter** algorithm written entirely in MIPS assembly language. The program reads input signal data and desired signal data from text files (.txt), performs matrix calculations to find the optimal filter coefficients. Finally, the program filters the input signal and calculates the **Minimum Mean Square Error (MMSE)**.

## 2. Program Execution Flow
The program is divided into 7 main parts (corresponding to the comments in the source code):

1. **Step 0: Memory Allocation (Heap Allocation):** Dynamically allocates memory for data arrays (Input, Desired, Output) and matrices/vectors for the algorithm (Autocorrelation, Cross-correlation, Coefficient matrix A).
2. **Step 1: File Reading and Parsing:** Reads content from input and desired files, then converts character strings to floating-point numbers (Float) and stores them in memory.
3. **Step 2: Statistics Calculation:** Calculates the Autocorrelation and Cross-correlation between the input signal and the desired signal to build the Wiener-Hopf equation.
4. **Step 3: Gaussian Elimination:** Applies the Gaussian Elimination method to solve the linear system of equations, thereby finding the Filter Coefficients.
5. **Step 4: Signal Filtering:** Uses the found coefficients to convolve with the input signal, producing the Filtered Output.
6. **Step 5: MMSE Calculation:** Compares the filtered signal with the desired signal to calculate the Minimum Mean Square Error (Direct MSE).
7. **Step 6: Output Results:** Prints the result array and MMSE value to the MARS Terminal, and writes them to the `output.txt` file.

## 3. File Structure
- `Wiener_Filter.asm`: The main source code of the program.
- `input19-44-21_11-Nov-25_10_10_1.txt`: The file containing the input signal array (default in code).
- `desired19-44-21_11-Nov-25_10_10.txt`: The file containing the desired signal array.
- `output.txt`: The output file (automatically created) containing the filtered results and the MMSE value.

## 4. Usage Instructions
### Software Requirements
- Java Runtime Environment (JRE).
- MARS 4.5 Simulator (`Mars4_5.jar`).

### How to run the program
1. Open the MARS 4.5 software.
2. Select **File -> Open** and open the `Wiener_Filter.asm` file.
3. Ensure that the input (`input...txt`) and desired (`desired...txt`) files are located in the **same directory** as the MARS software, or you need to configure the **absolute path** in the `.data` section of the source code if MARS reports a "Loi mo file." (File open error).
4. Press **F3** (Run -> Assemble) to compile the program.
5. Press **F5** (Run -> Go) to execute.
6. The results will be printed in the **Run I/O** window at the bottom of the MARS screen and saved to the `output.txt` file.

## 5. Parameter Configuration
You can change basic parameters in the `.data` section of the `Wiener_Filter.asm` source code:
- `input_filename`: Change the input file name.
- `desired_filename`: Change the desired file name.
- `outFilename`: Change the output file name.
- `M`: Filter order (Default: 10).
- `N`: Signal sample size/quantity (Default: 10).

## 6. Troubleshooting
- **Cannot read file error ("Loi mo file."):** MARS often uses the root directory of the `.jar` file as the working directory instead of the directory containing the `.asm` file. Try copying the text files to the same location as `Mars4_5.jar` or change the path in `.data` to an absolute path (e.g., `C:/path/to/input.txt`).
- The float parsing algorithm in the source code is written manually and is capable of handling negative numbers, integer parts, and fractional parts.
