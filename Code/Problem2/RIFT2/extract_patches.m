function patch = extract_patches(img, x, y, s, t)
% 提取图像块函数 - 支持旋转和双线性插值
%
% 输入参数：
%   img - 输入图像（支持多通道）
%   x   - 提取中心的x坐标
%   y   - 提取中心的y坐标  
%   s   - 块半径（实际块大小为2s+1 × 2s+1）
%   t   - 旋转角度（度）
%
% 输出参数：
%   patch - 提取的图像块

% 将图像转换为double类型以便处理
img = im2double(img);
% 获取图像尺寸
h = size(img,1);
w = size(img,2);
m = size(img,3);

% 对坐标进行取整和边界检查
x = round(x);
y = round(y);
% 确保坐标不超出图像边界
x(x<1) = 1;
x(x>w) = w;
y(y<1) = 1;
y(y>h) = h;

% 处理尺寸和角度参数
s = round(s);           % 块半径取整
t = t*pi/180;           % 角度转换为弧度

% 将多通道图像分离到cell数组中
imgch = cell(m,1);
for ch=1:m
    imgch{ch} = img(:,:,ch);
end

% 计算实际块大小
patchsize = s*2+1;

% 生成局部坐标网格
[xg,yg] = meshgrid(-s:s,-s:s);

% 构建旋转矩阵
R = [cos(t) -sin(t);...
     sin(t)  cos(t)];

% 应用旋转变换到局部坐标
xygrot = R*[xg(:)'; yg(:)'];
% 将旋转后的坐标平移到目标位置
xygrot(1,:) = xygrot(1,:) + x;
xygrot(2,:) = xygrot(2,:) + y;

% 提取旋转后的坐标
xr = xygrot(1,:)';  % 旋转后的x坐标
yr = xygrot(2,:)';  % 旋转后的y坐标

% 计算双线性插值所需的坐标
xf = floor(xr);     % x向下取整
yf = floor(yr);     % y向下取整
xp = xr-xf;         % x的小数部分
yp = yr-yf;         % y的小数部分

% 初始化输出图像块
patch = zeros(patchsize,patchsize,m);

% 找出在图像边界内的有效像素索引
vid = find(xf >= 1 & xf <= w-1 & yf >= 1 & yf <= h-1);
% 只保留有效像素的坐标
xf = xf(vid);
yf = yf(vid);
xp = xp(vid);
yp = yp(vid);

% 计算四个相邻像素的线性索引
ind1 = sub2ind([h,w],yf,xf);       % 左上像素
ind2 = sub2ind([h,w],yf,xf+1);     % 右上像素  
ind3 = sub2ind([h,w],yf+1,xf);     % 左下像素
ind4 = sub2ind([h,w],yf+1,xf+1);   % 右下像素

% 对每个通道分别处理
for ch=1:m
    % 双线性插值计算像素值
    ivec = (1-yp).*(xp.*imgch{ch}(ind2)+(1-xp).*imgch{ch}(ind1))+...
           (yp).*(xp.*imgch{ch}(ind4)+(1-xp).*imgch{ch}(ind3));
    
    % 初始化当前通道的块
    temp = zeros(patchsize,patchsize);
    % 将插值结果填入有效位置
    temp(vid) = (ivec);
    % 存储到输出块中
    patch(:,:,ch) = temp;
end

end