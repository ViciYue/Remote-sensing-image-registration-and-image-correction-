% LOWPASSFILTER - Constructs a low-pass butterworth filter.
%
% usage: f = lowpassfilter(sze, cutoff, n)
% 
% where: sze    is a two element vector specifying the size of filter 
%               to construct [rows cols].
%        cutoff is the cutoff frequency of the filter 0 - 0.5
%        n      is the order of the filter, the higher n is the sharper
%               the transition is. (n must be an integer >= 1).
%               Note that n is doubled so that it is always an even integer.
%
%                      1
%      f =    --------------------
%                              2n
%              1.0 + (w/cutoff)
%
% The frequency origin of the returned filter is at the corners.
%
% See also: HIGHPASSFILTER, HIGHBOOSTFILTER, BANDPASSFILTER
%

% Copyright (c) 1999 Peter Kovesi
% School of Computer Science & Software Engineering
% The University of Western Australia
% http://www.csse.uwa.edu.au/
% 
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, subject to the following conditions:
% 
% The above copyright notice and this permission notice shall be included in 
% all copies or substantial portions of the Software.
%
% The Software is provided "as is", without warranty of any kind.

% October 1999
% August  2005 - Fixed up frequency ranges for odd and even sized filters
%                (previous code was a bit approximate)

function f = lowpassfilter(sze, cutoff, n)
% 低通滤波器生成函数
%
% 输入参数：
%   sze    - 滤波器尺寸 [行数, 列数] 或标量（表示正方形尺寸）
%   cutoff - 截止频率，范围必须在0到0.5之间
%   n      - 滤波器阶数，必须为大于等于1的整数
%
% 输出参数：
%   f      - 生成的频域低通滤波器

% 检查截止频率参数是否在有效范围内
if cutoff < 0 | cutoff > 0.5
    error('截止频率必须在0到0.5之间');
end

% 检查滤波器阶数是否为有效整数
if rem(n,1) ~= 0 | n < 1
    error('滤波器阶数n必须为大于等于1的整数');
end

% 解析滤波器尺寸参数
if length(sze) == 1
    rows = sze; cols = sze;  % 如果是标量，创建正方形滤波器
else
    rows = sze(1); cols = sze(2);  % 否则分别获取行数和列数
end

% 设置X坐标矩阵，范围归一化到[-0.5, 0.5]
% 根据列数的奇偶性采用不同的处理方式
if mod(cols,2)
    xrange = [-(cols-1)/2:(cols-1)/2]/(cols-1);  % 奇数尺寸的情况
else
    xrange = [-cols/2:(cols/2-1)]/cols;          % 偶数尺寸的情况
end

% 设置Y坐标矩阵，范围归一化到[-0.5, 0.5]
% 根据行数的奇偶性采用不同的处理方式
if mod(rows,2)
    yrange = [-(rows-1)/2:(rows-1)/2]/(rows-1);  % 奇数尺寸的情况
else
    yrange = [-rows/2:(rows/2-1)]/rows;          % 偶数尺寸的情况
end

% 生成网格坐标
[x,y] = meshgrid(xrange, yrange);

% 计算每个像素到中心点的相对距离（半径）
radius = sqrt(x.^2 + y.^2);

% 生成巴特沃斯低通滤波器，并进行反FFT移位以符合MATLAB的频域表示惯例
% 滤波器公式：1/(1 + (半径/截止频率)^(2n))
f = ifftshift( 1.0 ./ (1.0 + (radius ./ cutoff).^(2*n)) );
end
