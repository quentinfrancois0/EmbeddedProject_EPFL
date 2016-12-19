from helpers import *

path_pic = './pics/lakeside.png'
path_bin = './bins/lakeside.bin'

img = load_image(path_pic)
arr = array_from_img(img)
lt24 = to_lt24(arr)
to_file(lt24, path_bin)
