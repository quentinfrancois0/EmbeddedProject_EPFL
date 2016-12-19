from helpers import *

path_bin = './bins/lakeside.bin'
path_pic = './pics/lakeside_rec.png'

lt24_rec = from_file(path_bin)
arr_rec = from_lt24 (lt24_rec)
img_rec = img_from_array(arr_rec)
save_image(img_rec, path_pic)
img_rec.show() #not needed just quicker
