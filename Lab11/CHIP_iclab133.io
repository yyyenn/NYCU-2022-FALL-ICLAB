######################################################
#                                                    #
#  Silicon Perspective, A Cadence Company            #
#  FirstEncounter IO Assignment                      #
#                                                    #
######################################################

Version: 2

#Example:
#Pad: I_CLK 		W

#define your iopad location here

#########################################
# NOTRH

Pad: VDDP0   N
Pad: GNDP0   N

Pad: VDDC0   N
Pad: GNDC0   N

Pad: VDDP1   N
Pad: GNDP1   N

#########################################
# EAST

Pad: O_VALID E
Pad: O_VALUE E

Pad: VDDP2   E
Pad: GNDP2   E

Pad: VDDC1   E
Pad: GNDC1   E

#########################################
# SOUTH

Pad: I_MATRIX           S
Pad: I_MATRIX_SIZE_0    S
Pad: I_MATRIX_SIZE_1    S
Pad: I_I_MAT_IDX        S
Pad: I_W_MAT_IDX        S

Pad: VDDC2               S
Pad: GNDC2               S
#########################################
# WEST

Pad: I_CLK      W
Pad: I_RESET    W
Pad: I_VALID    W
Pad: I_VALID_2  W

Pad: VDDC3       W
Pad: GNDC3       W

#########################################

Pad: PCLR SE PCORNER
Pad: PCUL NW PCORNER
Pad: PCUR NE PCORNER
Pad: PCLL SW PCORNER