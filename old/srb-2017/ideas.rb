# frozen_string_literal: true
#
# Part of SRB
# Copyright (C) 2017 Jeffrey Sharp
#
# SRB is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# SRB is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with SRB.  If not, see <http://www.gnu.org/licenses/>.
#

# clrb    !x
# clrw    !x
# clrl    !x
# beqs    br :==, short x
# beqw    br :==, near  x
# bnes    br :!=, short x
# bnew    br :!=, near  x
# bmis    
# bmiw    
# bpls    
# bplw    
# bccs    
# bccw    
# bcss    
# bcsw    
# bvcs    
# bvcw    
# bvss    
# bvsw    
# blos    
# blow    
# blss    
# blsw    
# bhis    br unsigned(:>) => short(x)
# bhiw    br unsigned(:>) => near(x)
# bhss    
# bhsw    
# bgts    
# bgtw    
# bges    
# bgew    
# blts    
# bltw    
# bles    
# blew    
# bzs     
# bzw     
# bnzs    
# bnzw    
# bsrs    bsr short(x)
# bsrw    bsr near(x)
# bras    bra short(x)
# braw    bra near(x)
# extbw   x ** i16
# extwl   x ** i32
# extbl   x ** i32
# jmp     jmp x
# jsr     jsr x
# negl    -x
# negxl   -x(x)
# notl    ~x
# pea     
# seqb    x.v = :==
# sneb    x.v = :!=
# smib    
# splb    
# sccb    
# scsb    
# svcb    
# svsb    
# slob    
# slsb    
# shib    
# shsb    
# sgtb    
# sgeb    
# sltb    
# sleb    
# szb     x.v = /z/
# snzb    x.v = /nz/
# sfb     x.v = true
# stb     x.v = false
# swapw   
# tpfw    
# tpfl    
# trap    
# tstb    
# tstw    
# tstl    
# unlk    
# wddatab 
# wddataw 
# wddatal 
# wdebugl 

# addl    y + x     y + _(x)
# addal   y + x     y + _(x)
# addil   y + x     y + i(x)
# addql   y + x     y + q(x)
# addxl             y + x(x)
# andl    y & x     y & _(x)
# andil   y & x     y & i(x)
# asll    y << x    y << sl(x)
# asrl    y << x    y << sl(x)
# bchgb   ~y[n]                   (y is memory location)
# bchgl   ~y[n]                   (y is register)
# bclrb   y[n] = 0                (y is memory location)
# bclrl   y[n] = 0                (y is register)
# bsetb   y[n] = 1                (y is memory location)
# bsetl   y[n] = 1                (y is register)
# btstb   test y[n]               (y is memory location)
# btstl   test y[n]               (y is register)
# cmpl    y <=> x   y <=> _(x)
# cmpal   y <=> x   y <=> _(x)
# cmpil   y <=> x   y <=> i(x)
# cpushl  
# divsw   y / x     y / sw(x)
# divsl   y / x     y / sl(x)
# divuw   y / x     y / uw(x)
# divul   y / x     y / ul(x)
# eorl    y ^ x     y / _(x)
# eoril   y ^ x     y / i(x)
# lea     y.val = ea(x)
# link
# lsll    y << x    y << ul(x)
# lsrl    y >> x    y >> ul(x)
# moveb   y.v = x
# movew   y.v = x
# movel   y.v = x
# moveaw  y.v = x
# moveal  y.v = x
# movecl  y.v = x
# moveml
# moveql  y.l = x   y.l = q(x)
# mulsw   y * x   y * sw(x)
# mulsl   y * x   y * sl(x)
# muluw   y * x   y * uw(x)
# mulul   y * x   y * ul(x)
# orl     y | x   y | _(x)
# oril    y | x   y | i(x)
# subl    y - x   y - _(x)
# subal   y - x   y - _(x)
# subil   y - x   y - i(x)
# subql   y - x   y - q(x)
# subxl           y - x(x)

