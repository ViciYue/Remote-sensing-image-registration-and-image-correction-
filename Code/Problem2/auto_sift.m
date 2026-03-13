function [registered_img, tform, error_stats, feature_points] = ...
         auto_sift(moving_img, fixed_img, moving_gray, fixed_gray)
% 基于自动特征匹配的几何校正
% 输入：
%   moving_img - 待校正影像（彩色）
%   fixed_img - 参考影像（彩色）
%   moving_gray - 待校正影像（灰度）
%   fixed_gray - 参考影像（灰度）
% 输出：
%   registered_img - 校正后的图像
%   tform - 几何变换对象
%   error_stats - 误差统计
%   feature_points - 特征点信息

    fprintf('开始自动特征匹配配准...\n');
    
    %% 检测SIFT特征点
    fprintf('检测SIFT特征点...\n');
    points_fixed = detectSIFTFeatures(fixed_gray);
    points_moving = detectSIFTFeatures(moving_gray);
    
    % 提取特征描述子
    [features_fixed, valid_points_fixed] = extractFeatures(fixed_gray, points_fixed);
    [features_moving, valid_points_moving] = extractFeatures(moving_gray, points_moving);
    
    %% 特征匹配 - 优化参数
    fprintf('进行特征匹配...\n');
    % 优化匹配参数以平衡数量和质量
    index_pairs = matchFeatures(features_fixed, features_moving, ...
        'MaxRatio', 0.6, ...      % 恢复到0.6以获得更多匹配
        'MatchThreshold', 50, ... % 恢复到50
        'Unique', true);
    
    if size(index_pairs, 1) < 4
        error('匹配点数量不足，无法计算变换矩阵！');
    end
    
    matched_points_fixed = valid_points_fixed(index_pairs(:, 1), :);
    matched_points_moving = valid_points_moving(index_pairs(:, 2), :);
    
    fprintf('找到 %d 对匹配点\n', size(matched_points_fixed, 1));
    
    %% 保存特征点信息
    feature_points.matched_fixed = matched_points_fixed;
    feature_points.matched_moving = matched_points_moving;
    feature_points.num_matches = size(matched_points_fixed, 1);
    
    %% 估计变换矩阵并使用RANSAC剔除误匹配
    fprintf('使用RANSAC估计变换矩阵...\n');
    
    % 尝试使用新版本的变换估计函数
    try
        % 使用 estimateGeometricTransform2D (推荐)
        [tform, inlier_idx] = estimateGeometricTransform2D(...
            matched_points_moving.Location, matched_points_fixed.Location, ...
            'projective', ...     % 使用投影变换
            'MaxDistance', 3, ... % 适当放宽距离阈值
            'MaxNumTrials', 2000, ...
            'Confidence', 99);
        
        inlier_points_moving = matched_points_moving(inlier_idx);
        inlier_points_fixed = matched_points_fixed(inlier_idx);
        
    catch
        % 回退到旧版本函数
        fprintf('使用旧版本estimateGeometricTransform...\n');
        [tform, inlier_points_fixed, inlier_points_moving] = estimateGeometricTransform(...
            matched_points_moving, matched_points_fixed, 'projective', ...
            'MaxNumTrials', 2000, ...
            'Confidence', 99, ...
            'MaxDistance', 3);    % 放宽最大距离
    end
    
    fprintf('RANSAC后保留 %d 对内点\n', size(inlier_points_fixed, 1));
    
    feature_points.inlier_fixed = inlier_points_fixed;
    feature_points.inlier_moving = inlier_points_moving;
    feature_points.num_inliers = size(inlier_points_fixed, 1);
    
    %% 应用几何变换
    output_view = imref2d(size(fixed_gray));
    registered_img = imwarp(moving_img, tform, 'OutputView', output_view);
    
    %% 计算配准误差
    if size(inlier_points_fixed, 1) > 0
        transformed_points = transformPointsForward(tform, inlier_points_moving.Location);
        original_points = inlier_points_fixed.Location;
        
        errors = sqrt(sum((transformed_points - original_points).^2, 2));
        
        error_stats.mean_error = mean(errors);
        error_stats.max_error = max(errors);
        error_stats.min_error = min(errors);
        error_stats.std_error = std(errors);
        error_stats.all_errors = errors;
        error_stats.rmse_error = sqrt(mean(errors.^2));
        error_stats.inlier_ratio = feature_points.num_inliers / feature_points.num_matches;
    else
        error_stats.mean_error = NaN;
        error_stats.max_error = NaN;
        error_stats.min_error = NaN;
        error_stats.std_error = NaN;
        error_stats.rmse_error = NaN;
        error_stats.inlier_ratio = 0;
        error_stats.all_errors = [];
    end
    
    %% 显示方法特定结果
    figure('Name', '自动特征匹配 - 匹配结果', 'Position', [100, 100, 1200, 600]);
    
    subplot(1, 2, 1);
    showMatchedFeatures(fixed_gray, moving_gray, matched_points_fixed, matched_points_moving, 'montage');
    title(sprintf('所有特征点匹配结果 (%d 对)', feature_points.num_matches));
    legend('参考影像特征点', '待校正影像特征点');
    
    subplot(1, 2, 2);
    showMatchedFeatures(fixed_gray, moving_gray, inlier_points_fixed, inlier_points_moving, 'montage');
    title(sprintf('RANSAC后的内点匹配 (%d 对)', feature_points.num_inliers));
    legend('参考影像内点', '待校正影像内点');
    
    %% 显示配准结果对比
    figure('Name', '自动特征匹配 - 配准结果', 'Position', [100, 100, 1500, 500]);
    
    subplot(1, 3, 1);
    imshow(moving_img);
    title('待校正图像');
    
    subplot(1, 3, 2);
    imshow(fixed_img);
    title('参考图像');
    
    subplot(1, 3, 3);
    imshow(registered_img);
    title('校正后图像');
    
    %% 输出统计信息
    fprintf('=== 配准结果统计 ===\n');
    fprintf('匹配点总数: %d\n', feature_points.num_matches);
    fprintf('内点数量: %d\n', feature_points.num_inliers);
    fprintf('内点比例: %.1f%%\n', error_stats.inlier_ratio * 100);
    fprintf('平均误差: %.2f 像素\n', error_stats.mean_error);
    fprintf('RMSE: %.2f 像素\n', error_stats.rmse_error);
    fprintf('最大误差: %.2f 像素\n', error_stats.max_error);
    fprintf('====================\n');
end