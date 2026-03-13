%用123序号注明程序算法流程，abc序号注明可视化或者分析流程。

addpath(genpath(pwd));
t_total = tic;    % 总计时
rng(234);
%% ============================================================
% 1. 读取图像

t_read= tic;
rgb_ref = imread('whu_ref.png');
rgb_mov = imread('whu_mov.png');
fprintf("[计时] 读取图像: %.3f 秒\n", toc(t_read));

[h, w, ~] = size(rgb_ref);
refView = imref2d([h w]);  

%% ============================================================
% 2. 灰度转换

t_gray=tic;
gray_ref = im2uint8(rgb2gray(rgb_ref));
gray_mov = im2uint8(rgb2gray(rgb_mov));
im1 = cat(3,gray_ref,gray_ref,gray_ref);
im2 = cat(3,gray_mov,gray_mov,gray_mov);
fprintf("[计时] 灰度转换: %.3f 秒\n", toc(t_gray));

%% ============================================================
% 3. 图像缩放（加速）

t_resize = tic;
scale = 0.8;
im1_s = imresize(im1, scale);
im2_s = imresize(im2, scale);
fprintf("[计时] 图像缩放: %.3f 秒\n", toc(t_resize));

%% ============================================================
% 4. RIFT2 特征检测

t_fd = tic;
[key1, m1, eo1] = FeatureDetection(im1_s, 4, 6, 3000);
[key2, m2, eo2] = FeatureDetection(im2_s, 4, 6, 3000);
fprintf("[计时] 特征检测: %.3f 秒\n", toc(t_fd));

%% ============================================================
% a.构建 MIM（用于可视化）

no = 6;
[yim,xim,~] = size(im1_s);
CS = zeros(yim,xim,no);

for j=1:no
    for i=1:4
        CS(:,:,j) = CS(:,:,j) + abs(eo1{i,j});
    end
end
[~, MIM] = max(CS,[],3);

%% ============================================================
% 5. 主方向计算

t_ori = tic;
kpts1 = kptsOrientation(key1, m1, 1, 96);
kpts2 = kptsOrientation(key2, m2, 1, 96);
fprintf("[计时] 主方向: %.3f 秒\n", toc(t_ori));

%% ============================================================
% 6. 生成描述子

t_desc = tic;
des1 = FeatureDescribe(im1_s, eo1, kpts1, 96, 6, 6);
des2 = FeatureDescribe(im2_s, eo2, kpts2, 96, 6, 6);
fprintf("[计时] 描述子: %.3f 秒\n", toc(t_desc));

%% ============================================================
% 7. 初始匹配

t_match = tic;
[indexPairs, ~] = matchFeatures(des1', des2', 'MaxRatio',1,'MatchThreshold',100);

kpts1 = kpts1'; 
kpts2 = kpts2';
mp1 = kpts1(indexPairs(:,1),1:2);
mp2 = kpts2(indexPairs(:,2),1:2);

% 去重
[mp2,IA] = unique(mp2,'rows');
mp1 = mp1(IA,:);

mp1 = mp1 ./ scale;
mp2 = mp2 ./ scale;
fprintf("[计时] 特征匹配: %.3f 秒\n", toc(t_match));

%% ============================================================
% (b)Figure 1：关键点 + MIM
figure;
subplot(1,2,1);
imshow(im1_s(:,:,1)); hold on;
plot(key1(1,:), key1(2,:), 'r.');
title("关键点分布");

subplot(1,2,2);
imagesc(MIM);
axis image; colormap jet; colorbar;
title("MIM（最大方向索引图）");
%% ============================================================
% 8. 使用 RANSAC 求解 Projective H

t_homo = tic;

[tform, inlierIdx] = estimateGeometricTransform2D(...
    mp2, mp1, 'projective',...
    'MaxNumTrials',5000,'MaxDistance',3,'Confidence',95);
H = tform.T;  
in1 = mp1(inlierIdx,:);
in2 = mp2(inlierIdx,:);

fprintf("[计时] RANSAC + 单应性求解: %.3f 秒\n", toc(t_homo));
fprintf("RANSAC 内点数：%d / %d\n", length(in1), length(mp1));
%% ============================================================
% (c)Figure 2：初始匹配 + 内点匹配
% ============================================================
figure;
subplot(1,2,1);
showMatchedFeatures(rgb_ref, rgb_mov, mp1, mp2, 'montage');
title("初始匹配");
subplot(1,2,2);
showMatchedFeatures(rgb_ref, rgb_mov, in1, in2, 'montage');
title("RANSAC 内点");

H_final = H;   

%% 
% 10. 图像变换

t_warp = tic;
rgb_mov_reg = imwarp(rgb_mov, projective2d(H_final), 'OutputView', refView);
fprintf("[计时] 图像变换: %.3f 秒\n", toc(t_warp));

%% d.计算残差 Figure3:残差热力图
in2_trans = transformPointsForward(projective2d(H_final), in2);
errors = sqrt(sum((in1 - in2_trans).^2, 2));

fprintf("平均重投影误差: %.3f px\n", mean(errors));
fprintf("最大重投影误差: %.3f px\n", max(errors));


figure;

% 底图灰度（轴 ax1）
ax1 = axes;
imshow(gray_ref, 'Parent', ax1);
title(sprintf('残差热力图 (实际最大误差: %.2f px)', max(errors)), ...
      'FontSize', 14, 'FontWeight', 'bold');
hold(ax1, 'on');

%顶层散点（轴 ax2）
ax2 = axes;
scatter(ax2, in1(:,1), in1(:,2), 60, errors, 'filled', ...
    'MarkerEdgeColor','k','LineWidth',0.5,'MarkerFaceAlpha',0.85);
hold(ax2, 'on');

% ax2 覆盖在 ax1 上方，但透明
set(ax2, 'Color','none');
set(ax2, 'XLim', ax1.XLim, 'YLim', ax1.YLim, ...
         'YDir','reverse','Visible','off');

%使用统一的坐标轴系统
colormap(ax2, jet);
clim(ax2, [0 20]);% 设置颜色范围
c = colorbar(ax2);% 创建颜色条
c.Ticks = 0:5:20; 
c.TickLabels = {'0', '5', '10', '15', '20+'};

% 颜色条样式
c.Color = 'w';
c.Label.String = '重投影误差 (像素)';
c.Label.Color = 'w';
c.Label.FontSize = 12;
c.TickDirection = 'out';
c.FontSize = 11;

%标记最大误差点
[~, max_idx] = max(errors);
scatter(ax2, in1(max_idx,1), in1(max_idx,2), 150, ...
        'w', 'x', 'LineWidth', 2);

text(in1(max_idx,1)+10, in1(max_idx,2), '最大误差点', ...
     'Color','white','FontSize',12,'FontWeight','bold');

fprintf("残差热力图已生成\n");
%% 
% e.残差误差统计

fprintf("\n=========== 内点残差误差统计报告 ===========\n");
fprintf("内点数量：%d\n", length(errors));
fprintf("----------------------------------------------\n");

fprintf("平均误差   (Mean)      : %.4f px\n", mean(errors));
fprintf("最大误差   (Max)       : %.4f px\n", max(errors));
fprintf("最小误差   (Min)       : %.4f px\n", min(errors));
fprintf("标准差     (Std)       : %.4f px\n", std(errors));
fprintf("中位数误差 (Median)    : %.4f px\n", median(errors));

% 误差分位统计
fprintf("误差 P25               : %.4f px\n", prctile(errors,25));
fprintf("误差 P50 (中位)        : %.4f px\n", prctile(errors,50));
fprintf("误差 P75               : %.4f px\n", prctile(errors,75));

% 均方根误差 RMSE
rmse = sqrt(mean(errors.^2));
fprintf("均方根误差 (RMSE)      : %.4f px\n", rmse);

% 稳定性指标：变异系数 CV
cv = std(errors) / (mean(errors)+eps);
fprintf("变异系数 (CV)          : %.4f\n", cv);

fprintf("----------------------------------------------\n");

% 判断质量
if mean(errors) < 2
    fprintf("评价：配准质量优秀（误差非常小）\n");
elseif mean(errors) < 5
    fprintf("评价：配准质量良好（误差可接受）\n");
else
    fprintf("评价：配准质量较差（误差偏大，需要检查匹配）\n");
end

fprintf("==============================================\n\n");

%% 
% f.Figure 5：参考图 + 原图 + 配准图

figure;
subplot(1,3,1); imshow(rgb_ref); title('参考图');
subplot(1,3,2); imshow(rgb_mov); title('原始待矫正图');
subplot(1,3,3); imshow(rgb_mov_reg); title('配准结果');

%% 
% 11. 总时间

fprintf("\n===== RIFT2 配准完成，总耗时： %.3f 秒 =====\n", toc(t_total));
fprintf("最终 H 矩阵：\n");
disp(H_final);

% 显示变换矩阵的分解信息（用于分析）
fprintf("\n=== 变换矩阵分解信息 ===\n");
theta_rad = atan2(H_final(2,1), H_final(1,1));
fprintf("旋转角度: %.3f rad (%.2f°)\n", theta_rad, rad2deg(theta_rad));

sx = sqrt(H_final(1,1)^2 + H_final(2,1)^2);
sy = sqrt(H_final(1,2)^2 + H_final(2,2)^2);
fprintf("X方向缩放: %.4f\n", sx);
fprintf("Y方向缩放: %.4f\n", sy);
fprintf("平移量: [%.2f, %.2f] px\n", H_final(3,1), H_final(3,2));