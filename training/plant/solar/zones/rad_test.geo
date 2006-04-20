# geometry of rad_test defined in: ../zones/rad_test.geo
GEN  rad_test  rad_test describes a...  # type, name, descr
      16       8   0.000    # vertices, surfaces, rotation angle
#  X co-ord, Y co-ord, Z co-ord
      5.50000     1.00000     0.00000  # vert   1
     10.00000     1.00000     0.00000  # vert   2
     10.00000     4.50000     0.00000  # vert   3
      5.50000     4.50000     0.00000  # vert   4
      5.50000     1.00000     2.70000  # vert   5
     10.00000     1.00000     2.70000  # vert   6
     10.00000     4.50000     2.70000  # vert   7
      5.50000     4.50000     2.70000  # vert   8
      7.00000     1.00000     1.00000  # vert   9
      9.00000     1.00000     1.00000  # vert  10
      9.00000     1.00000     2.10000  # vert  11
      7.00000     1.00000     2.10000  # vert  12
      9.50000     4.50000     0.00000  # vert  13
      8.70000     4.50000     0.00000  # vert  14
      8.70000     4.50000     2.10000  # vert  15
      9.50000     4.50000     2.10000  # vert  16
# no of vertices followed by list of associated vert
  10,  1,  2,  6,  5,  1,  9, 12, 11, 10,  9,
   4,  2,  3,  7,  6,
   8,  3, 13, 16, 15, 14,  4,  8,  7,
   4,  4,  1,  5,  8,
   4,  5,  6,  7,  8,
   6,  1,  4, 14, 13,  3,  2,
   4,  9, 10, 11, 12,
   4, 13, 14, 15, 16,
# unused index
 0,0,0,0,0,0,0,0
# surfaces indentation (m)
 0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00
    3   0   0   0    # default insolation distribution
# surface attributes follow: 
# id  surface      geom  loc/  construction environment
# no  name         type  posn  name         other side
  1, south         OPAQ  VERT  ext_wall     EXTERIOR       
  2, right         OPAQ  VERT  block_part   heatexch       
  3, back_dg       OPAQ  VERT  block_part   passage        
  4, left          OPAQ  VERT  block_part   direct_gain    
  5, ceiling       OPAQ  CEIL  ceiling      roof           
  6, floor         OPAQ  FLOR  floor        GROUND         
  7, glaz          TRAN  VERT  dbl_glz      EXTERIOR       
  8, door          OPAQ  VERT  door         passage        
# base
  6  0  0  0  0  0    15.75 0