import random as rd

f_DRAM = open("./dram.dat", "w")

C_STATUS = [0, 1, 3]
D_INFO_TYPE = [0, 1, 2]
FOOD_ID = [1, 2, 3]

def fill_with_zeros(s, t):
    ss = ""
    for i in range(t-len(s)):
        ss += "0"
    
    ss += s
    return ss
    
def four_bin_to_hex(s):
    ss1 = ""
    ss2 = ""
    sl = []
    for i in range(len(s)):
        if i <= 7:
            ss1 += s[i]
        elif i > 7 and i < len(s):
            ss2 += s[i]
        
    sl.append(hex(int(ss1, 2))[2:4])
    sl.append(hex(int(ss2, 2))[2:4])
    # print(sl[0], sl[1])
    return sl

def res_zero():
    total = hex(rd.randint(120, 255))[2:4] # limit of order of the restaurant
    food1 = hex(0)[2:4]
    food2 = hex(0)[2:4]
    food3 = hex(0)[2:4]
    return total, food1, food2, food3

def res_random():
    temp1 = hex(rd.randint(120, 255))[2:4] # limit of order of the restaurant
    temp2 = hex(rd.randint(10, 100))[2:4]
    temp3 = hex(rd.randint(0, (int(temp1, 16)-int(temp2, 16)-1)))[2:4]
    temp4 = hex(rd.randint(0, (int(temp1, 16)-int(temp2, 16)-int(temp3, 16)-1)))[2:4]
    return temp1, temp2, temp3, temp4

def res_full_hiegh():
    flag = rd.randint(0, 1)
    f1 = rd.randint(82, 83)
    f2 = rd.randint(82, 83)
    f3 = rd.randint(82, 83)
    total_limit = rd.randint((f1 + f2 + f3) + 1, 255)
    # total_limit = f1 + f2 + f3 + rd.randint(0,3)
    temp1 = hex(total_limit)[2:4] # limit of order of the restaurant
    temp2 = hex(f1)[2:4]
    temp3 = hex(f2)[2:4]
    temp4 = hex(f3)[2:4]
    return temp1, temp2, temp3, temp4

def res_full_normal():
    flag = rd.randint(0, 1)
    f1 = rd.randint(0, 84)
    f2 = rd.randint(0, 84)
    f3 = rd.randint(0, 84)
    total_limit = rd.randint((f1 + f2 + f3) + 1, (f1 + f2 + f3) + 2)
    # total_limit = f1 + f2 + f3 + rd.randint(0,3)
    temp1 = hex(total_limit)[2:4] # limit of order of the restaurant
    temp2 = hex(f1)[2:4]
    temp3 = hex(f2)[2:4]
    temp4 = hex(f3)[2:4]
    return temp1, temp2, temp3, temp4

def res_nofood():
    
    f1 = rd.randint(0, 3)
    f2 = rd.randint(0, 3)
    f3 = rd.randint(0, 3)
    total_limit = rd.randint(250, 255)
    # total_limit = f1 + f2 + f3 + rd.randint(0,3)
    temp1 = hex(total_limit)[2:4] # limit of order of the restaurant
    temp2 = hex(f1)[2:4]
    temp3 = hex(f2)[2:4]
    temp4 = hex(f3)[2:4]
    
    return temp1, temp2, temp3, temp4
def res_empty():
    #f1 = rd.randint(0, 10)
    #f2 = rd.randint(0, 10)
    #f3 = rd.randint(0, 10)
    temp1 = hex(0)[2:4] # limit of order of the restaurant
    temp2 = hex(0)[2:4]
    temp3 = hex(0)[2:4]
    temp4 = hex(0)[2:4]
    return temp1, temp2, temp3, temp4

def cmt_empty():
    cmt_zero_temp1 = hex(0)[2:4]
    cmt_zero_temp2 = hex(0)[2:4]
    cmt_zero_temp3 = hex(0)[2:4]
    cmt_zero_temp4 = hex(0)[2:4]
    return cmt_zero_temp1, cmt_zero_temp2, cmt_zero_temp3, cmt_zero_temp4
def cmt_full():
    cmt_zero_temp1 = hex(255)[2:4]
    cmt_zero_temp2 = hex(255)[2:4]
    cmt_zero_temp3 = hex(255)[2:4]
    cmt_zero_temp4 = hex(255)[2:4]
    return cmt_zero_temp1, cmt_zero_temp2, cmt_zero_temp3, cmt_zero_temp4
def cmt_one_random():
    status = rd.randint(1, 2)
    food_id = rd.randint(0, 2)
    c1_status = fill_with_zeros(str(bin(C_STATUS[status])[2:]), 2)
    c1_res_id = fill_with_zeros(str(bin(rd.randint(0, 255))[2:]), 8)
    c1_food_id = fill_with_zeros(str(bin(FOOD_ID[food_id])[2:]), 2)
    c1_order = fill_with_zeros(str(bin(rd.randint(1, 15))[2:]), 4)

    # print(fill_with_zeros(c1_status, 2), fill_with_zeros(c1_res_id, 8), fill_with_zeros(c1_food_id, 2), fill_with_zeros(c1_order, 4))
    temp12 = four_bin_to_hex(c1_status + c1_res_id + c1_food_id + c1_order)


    temp1 = temp12[0]
    temp2 = temp12[1]
    temp3 = hex(0)[2:4]
    temp4 = hex(0)[2:4]
    return temp1, temp2, temp3, temp4

def cmt_one_vip():
    status = 2
    food_id = rd.randint(0, 2)
    c1_status = fill_with_zeros(str(bin(C_STATUS[status])[2:]), 2)
    c1_res_id = fill_with_zeros(str(bin(rd.randint(0, 255))[2:]), 8)
    c1_food_id = fill_with_zeros(str(bin(FOOD_ID[food_id])[2:]), 2)
    c1_order = fill_with_zeros(str(bin(rd.randint(1, 15))[2:]), 4)

    # print(fill_with_zeros(c1_status, 2), fill_with_zeros(c1_res_id, 8), fill_with_zeros(c1_food_id, 2), fill_with_zeros(c1_order, 4))
    temp12 = four_bin_to_hex(c1_status + c1_res_id + c1_food_id + c1_order)


    temp1 = temp12[0]
    temp2 = temp12[1]
    temp3 = hex(0)[2:4]
    temp4 = hex(0)[2:4]
    # print(c1_status , ' ' , int(c1_res_id, 2), ' ' , c1_food_id, ' ', int(c1_order, 2))
    return temp1, temp2, temp3, temp4

def cmt_one_normal():
    status = 1
    food_id = rd.randint(0, 2)
    c1_status = fill_with_zeros(str(bin(C_STATUS[status])[2:]), 2)
    c1_res_id = fill_with_zeros(str(bin(rd.randint(0, 255))[2:]), 8)
    c1_food_id = fill_with_zeros(str(bin(FOOD_ID[food_id])[2:]), 2)
    c1_order = fill_with_zeros(str(bin(rd.randint(1, 15))[2:]), 4)

    # print(fill_with_zeros(c1_status, 2), fill_with_zeros(c1_res_id, 8), fill_with_zeros(c1_food_id, 2), fill_with_zeros(c1_order, 4))
    temp = four_bin_to_hex(c1_status + c1_res_id + c1_food_id + c1_order)


    cmt_one_normal_temp1 = temp[0]
    cmt_one_normal_temp2 = temp[1]
    cmt_one_normal_temp3 = hex(0)[2:4]
    cmt_one_normal_temp4 = hex(0)[2:4]
    return cmt_one_normal_temp1, cmt_one_normal_temp2, cmt_one_normal_temp3, cmt_one_normal_temp4

def cmt_two_random():
    status1 = rd.randint(1, 2)
    food_id = rd.randint(0, 2)
    c1_status = fill_with_zeros(str(bin(C_STATUS[status1])[2:]), 2)
    c1_res_id = fill_with_zeros(str(bin(rd.randint(0, 255))[2:]), 8)
    c1_food_id = fill_with_zeros(str(bin(FOOD_ID[food_id])[2:]), 2)
    c1_order = fill_with_zeros(str(bin(rd.randint(1, 15))[2:]), 4)
    # print(fill_with_zeros(c1_status, 2), fill_with_zeros(c1_res_id, 8), fill_with_zeros(c1_food_id, 2), fill_with_zeros(c1_order, 4))

    temp12 = four_bin_to_hex(c1_status + c1_res_id + c1_food_id + c1_order)

    temp1 = temp12[0]
    temp2 = temp12[1]
    status2 = 0
    if status1 == 2:
        status2 = rd.randint(1, 2)
    elif status1 == 1:
        status2 = 1
    food_id = rd.randint(0, 2)
    c2_status = fill_with_zeros(str(bin(C_STATUS[status2])[2:]), 2)
    c2_res_id = fill_with_zeros(str(bin(rd.randint(0, 255))[2:]), 8)
    c2_food_id = fill_with_zeros(str(bin(FOOD_ID[food_id])[2:]), 2)
    c2_order = fill_with_zeros(str(bin(rd.randint(1, 15))[2:]), 4)
    # print(fill_with_zeros(c2_status, 2), fill_with_zeros(c2_res_id, 8), fill_with_zeros(c2_food_id, 2), fill_with_zeros(c2_order, 4))

    temp34 = four_bin_to_hex(c2_status + c2_res_id + c2_food_id + c2_order)

    temp3 = temp34[0]
    temp4 = temp34[1]
    
    return temp1, temp2, temp3, temp4
def cmt_two_novip():
    status1 = 1
    food_id = rd.randint(0, 2)
    c1_status = fill_with_zeros(str(bin(C_STATUS[status1])[2:]), 2)
    c1_res_id = fill_with_zeros(str(bin(rd.randint(0, 255))[2:]), 8)
    c1_food_id = fill_with_zeros(str(bin(FOOD_ID[food_id])[2:]), 2)
    c1_order = fill_with_zeros(str(bin(rd.randint(1, 15))[2:]), 4)
    # print(fill_with_zeros(c1_status, 2), fill_with_zeros(c1_res_id, 8), fill_with_zeros(c1_food_id, 2), fill_with_zeros(c1_order, 4))

    temp12 = four_bin_to_hex(c1_status + c1_res_id + c1_food_id + c1_order)

    temp1 = temp12[0]
    temp2 = temp12[1]
    status2 = 1
    food_id = rd.randint(0, 2)
    c2_status = fill_with_zeros(str(bin(C_STATUS[status2])[2:]), 2)
    c2_res_id = fill_with_zeros(str(bin(rd.randint(0, 255))[2:]), 8)
    c2_food_id = fill_with_zeros(str(bin(FOOD_ID[food_id])[2:]), 2)
    c2_order = fill_with_zeros(str(bin(rd.randint(1, 15))[2:]), 4)
    # print(fill_with_zeros(c2_status, 2), fill_with_zeros(c2_res_id, 8), fill_with_zeros(c2_food_id, 2), fill_with_zeros(c2_order, 4))

    temp34 = four_bin_to_hex(c2_status + c2_res_id + c2_food_id + c2_order)

    temp3 = temp34[0]
    temp4 = temp34[1]
    
    return temp1, temp2, temp3, temp4

def cmt_two_onevip():
    status1 = 2
    food_id = rd.randint(0, 2)
    c1_status = fill_with_zeros(str(bin(C_STATUS[status1])[2:]), 2)
    c1_res_id = fill_with_zeros(str(bin(rd.randint(0, 255))[2:]), 8)
    c1_food_id = fill_with_zeros(str(bin(FOOD_ID[food_id])[2:]), 2)
    c1_order = fill_with_zeros(str(bin(rd.randint(1, 15))[2:]), 4)
    # print(fill_with_zeros(c1_status, 2), fill_with_zeros(c1_res_id, 8), fill_with_zeros(c1_food_id, 2), fill_with_zeros(c1_order, 4))

    temp12 = four_bin_to_hex(c1_status + c1_res_id + c1_food_id + c1_order)

    temp1 = temp12[0]
    temp2 = temp12[1]
    status2 = 1
    food_id = rd.randint(0, 2)
    c2_status = fill_with_zeros(str(bin(C_STATUS[status2])[2:]), 2)
    c2_res_id = fill_with_zeros(str(bin(rd.randint(0, 255))[2:]), 8)
    c2_food_id = fill_with_zeros(str(bin(FOOD_ID[food_id])[2:]), 2)
    c2_order = fill_with_zeros(str(bin(rd.randint(1, 15))[2:]), 4)
    # print(fill_with_zeros(c2_status, 2), fill_with_zeros(c2_res_id, 8), fill_with_zeros(c2_food_id, 2), fill_with_zeros(c2_order, 4))

    temp34 = four_bin_to_hex(c2_status + c2_res_id + c2_food_id + c2_order)

    temp3 = temp34[0]
    temp4 = temp34[1]
    
    return temp1, temp2, temp3, temp4

def cmt_two_twovip():
    status1 = 2
    food_id = rd.randint(0, 2)
    c1_status = fill_with_zeros(str(bin(C_STATUS[status1])[2:]), 2)
    c1_res_id = fill_with_zeros(str(bin(rd.randint(0, 255))[2:]), 8)
    c1_food_id = fill_with_zeros(str(bin(FOOD_ID[food_id])[2:]), 2)
    c1_order = fill_with_zeros(str(bin(rd.randint(1, 15))[2:]), 4)
    # print(fill_with_zeros(c1_status, 2), fill_with_zeros(c1_res_id, 8), fill_with_zeros(c1_food_id, 2), fill_with_zeros(c1_order, 4))

    temp12 = four_bin_to_hex(c1_status + c1_res_id + c1_food_id + c1_order)

    temp1 = temp12[0]
    temp2 = temp12[1]
    status2 = 2
    food_id = rd.randint(0, 2)
    c2_status = fill_with_zeros(str(bin(C_STATUS[status2])[2:]), 2)
    c2_res_id = fill_with_zeros(str(bin(rd.randint(0, 255))[2:]), 8)
    c2_food_id = fill_with_zeros(str(bin(FOOD_ID[food_id])[2:]), 2)
    c2_order = fill_with_zeros(str(bin(rd.randint(1, 15))[2:]), 4)
    # print(fill_with_zeros(c2_status, 2), fill_with_zeros(c2_res_id, 8), fill_with_zeros(c2_food_id, 2), fill_with_zeros(c2_order, 4))

    temp34 = four_bin_to_hex(c2_status + c2_res_id + c2_food_id + c2_order)

    temp3 = temp34[0]
    temp4 = temp34[1]
    
    return temp1, temp2, temp3, temp4
def cmt_wrong_res_food():
    status1 = rd.randint(1, 2)
    food_id = 2
    c1_status = fill_with_zeros(str(bin(C_STATUS[status1])[2:]), 2)
    c1_res_id = fill_with_zeros(str(bin(255)[2:]), 8)
    c1_food_id = fill_with_zeros(str(bin(FOOD_ID[food_id])[2:]), 2)
    c1_order = fill_with_zeros(str(bin(rd.randint(1, 15))[2:]), 4)
    # print(fill_with_zeros(c1_status, 2), fill_with_zeros(c1_res_id, 8), fill_with_zeros(c1_food_id, 2), fill_with_zeros(c1_order, 4))

    temp12 = four_bin_to_hex(c1_status + c1_res_id + c1_food_id + c1_order)

    temp1 = temp12[0]
    temp2 = temp12[1]
    status2 = 0
    if status1 == 2:
        status2 = rd.randint(1, 2)
    elif status1 == 1:
        status2 = 1
    c2_status = fill_with_zeros(str(bin(C_STATUS[status2])[2:]), 2)
    c2_res_id = fill_with_zeros(str(bin(255)[2:]), 8)
    c2_food_id = fill_with_zeros(str(bin(FOOD_ID[food_id])[2:]), 2)
    c2_order = fill_with_zeros(str(bin(rd.randint(1, 15))[2:]), 4)
    # print(fill_with_zeros(c2_status, 2), fill_with_zeros(c2_res_id, 8), fill_with_zeros(c2_food_id, 2), fill_with_zeros(c2_order, 4))

    temp34 = four_bin_to_hex(c2_status + c2_res_id + c2_food_id + c2_order)

    temp3 = temp34[0]
    temp4 = temp34[1]
    
    return temp1, temp2, temp3, temp4

def GEN_DRAM():
    flag = True
    for i in range(0x10000, 0x107FF, 4) :
        id_count = (int)((i- 65536) / 8)
        if flag:
            print(id_count)
            f_DRAM.write('@' + format(i, 'x') + '\n')
            if id_count <= 169 : # empty res
                res1, res2, res3, res4 = res_empty()
            else :
                res1, res2, res3, res4 = res_nofood()
            #if id_count <= 19 : #man busy
            #    res1, res2, res3, res4 = res_random()
            #elif 19 < id_count <= 39 : #nofood
            #    res1, res2, res3, res4 = res_nofood()
            #elif 39 < id_count <= 59 : #no cus
            #    res1, res2, res3, res4 = res_random()
            #elif 59 < id_count <= 69 : #res busy
            #    res1, res2, res3, res4 = res_full_normal()
            #elif 69 < id_count <= 79 : #res busy
            #    res1, res2, res3, res4 = res_full_normal()
            #else :
            #    res1, res2, res3, res4 = res_random()
            print(int(res1, 16), ' ' ,int(res2, 16), ' ' , int (res3, 16), ' ', int(res4, 16))
            f_DRAM.write(res1 + ' ' + res2 + ' ' + res3 + ' ' + res4 + '\n')
            flag = False
        elif not flag:
            
            f_DRAM.write('@' + format(i, 'x') + '\n')
            if id_count <= 119 : #man busy
                cmt1, cmt2, cmt3, cmt4 = cmt_empty()
            elif 119 < id_count <= 169 : #nofood
                cmt1, cmt2, cmt3, cmt4 = cmt_full()
            else :
                cmt1, cmt2, cmt3, cmt4 = cmt_two_random()
            #if id_count <= 19 : #man busy
            #   cmt1, cmt2, cmt3, cmt4 = cmt_two_random()
            #elif 19 < id_count <= 39 : #nofood
            #    cmt1, cmt2, cmt3, cmt4 = cmt_two_random()
            #elif 39 < id_count <= 59 : #no cus
            #    cmt1, cmt2, cmt3, cmt4 = cmt_empty()
            #elif 59 < id_count <= 69 : #res busy
            #    cmt1, cmt2, cmt3, cmt4 = cmt_two_random()
            #elif 69 < id_count <= 79 : #res busy
            #    cmt1, cmt2, cmt3, cmt4 = cmt_two_random()
            #elif 79 < id_count <= 99 : #wrong man
            #    cmt1, cmt2, cmt3, cmt4 = cmt_empty()
            #elif 99 < id_count <= 119 : #wrong man
            #    cmt1, cmt2, cmt3, cmt4 = cmt_wrong_res_food()
            #elif 119 < id_count <= 139 : #wrong man
            #    cmt1, cmt2, cmt3, cmt4 = cmt_wrong_res_food()
            #else :
            #    cmt1, cmt2, cmt3, cmt4 = cmt_two_random()
                
            # cmt1, cmt2, cmt3, cmt4 = cmt_one_vip()
            print(int(cmt1, 16), ' ' ,int(cmt2, 16), ' ' , int (cmt3, 16), ' ', int(cmt4, 16))
            f_DRAM.write(cmt1 + ' ' + cmt2 + ' ' + cmt3 + ' ' + cmt4 + '\n')
            flag = True

if __name__ == '__main__' :
    GEN_DRAM()

f_DRAM.close()
