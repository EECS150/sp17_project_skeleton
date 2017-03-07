#include "types.h"

#define COUNTER_RST (*((volatile uint32_t*) 0x80000018))
#define CYCLE_COUNTER (*((volatile uint32_t*)0x80000010))
#define INSTRUCTION_COUNTER (*((volatile uint32_t*)0x80000014))

#define GPIO_FIFO_EMPTY (*((volatile uint32_t*)0x80000020) & 0x01)
#define GPIO_FIFO_DATA (*((volatile uint32_t*)0x80000024))
#define DIP_SWITCHES (*((volatile uint32_t*)0x80000028) & 0xFF)
#define LED_CONTROL (*((volatile uint32_t*)0x80000030))

#define TONE_GEN_OUTPUT_ENABLE (*((volatile uint32_t*)0x80000034))
#define TONE_GEN_TONE_INPUT (*((volatile uint32_t*)0x80000038))

#define AC97_FULL (*((volatile uint32_t*)0x80000040) & 0x01)
#define AC97_DATA (*((volatile uint32_t*)0x80000044))
#define AC97_VOLUME (*((volatile uint32_t*)0x80000048))
