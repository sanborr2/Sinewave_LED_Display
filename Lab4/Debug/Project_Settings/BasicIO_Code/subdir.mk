################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../Project_Settings/BasicIO_Code/BasicIO.c 

OBJS += \
./Project_Settings/BasicIO_Code/BasicIO.o 

C_DEPS += \
./Project_Settings/BasicIO_Code/BasicIO.d 


# Each subdirectory must supply rules for building sources it contributes
Project_Settings/BasicIO_Code/%.o: ../Project_Settings/BasicIO_Code/%.c
	@echo 'Building file: $<'
	@echo 'Invoking: Cross ARM C Compiler'
	arm-none-eabi-gcc -mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16 -O0 -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections  -g3 -I"../Sources" -I"../Includes" -std=c99 -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -c -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


