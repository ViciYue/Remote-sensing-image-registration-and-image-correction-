function [corrected_img, tform, stats] = surf_correction(data_folder)
% SURF特征匹配与图像纠正

    fprintf('开始SURF图像纠正...\n');

    %% 1. 图像读取与预处理
    % 读取图像
    distorted_img = imread(fullfile(data_folder, '扭曲图片.png'));
    reference_img = imread(fullfile(data_folder, '正常图片.png'));

    % 转换为灰度图
    if size(distorted_img, 3) == 3
        distorted_gray = rgb2gray(distorted_img);
    else
        distorted_gray = distorted_img;
    end

    if size(reference_img, 3) == 3
        reference_gray = rgb2gray(reference_img);
    else
        reference_gray = reference_img;
    end

    % 图像增强：直方图均衡化
    distorted_gray = histeq(distorted_gray);
    reference_gray = histeq(reference_gray);

    %% 2. SURF特征匹配与图像纠正
    % SURF特征检测
    points_distorted = detectSURFFeatures(distorted_gray, 'NumOctaves', 4, 'NumScaleLevels', 6);
    points_reference = detectSURFFeatures(reference_gray, 'NumOctaves', 4, 'NumScaleLevels', 6);

    % 提取特征描述子
    [features_distorted, valid_points_distorted] = extractFeatures(distorted_gray, points_distorted);
    [features_reference, valid_points_reference] = extractFeatures(reference_gray, points_reference);

    % 特征匹配
    index_pairs = matchFeatures(features_distorted, features_reference, ...
        'MatchThreshold', 1.0, 'MaxRatio', 0.6, 'Unique', true);

    matched_points_distorted = valid_points_distorted(index_pairs(:,1));
    matched_points_reference = valid_points_reference(index_pairs(:,2));

    % 使用PROSAC估计变换矩阵
    [tform, inlier_idx, status] = estimateGeometricTransform2D(...
        matched_points_distorted.Location, ...
        matched_points_reference.Location, ...
        'projective', 'MaxDistance', 8, 'Confidence', 99, 'MaxNumTrials', 1500);

    if status ~= 0
        error('变换矩阵估计失败！');
    end

    % 应用变换
    output_view = imref2d(size(reference_gray));
    corrected_img = imwarp(distorted_img, tform, 'OutputView', output_view);
    corrected_gray = imwarp(distorted_gray, tform, 'OutputView', output_view);

    %% 3. 精确度评估计算
    % 获取内点并计算误差
    inlier_points_distorted = matched_points_distorted(inlier_idx);
    inlier_points_reference = matched_points_reference(inlier_idx);

    distorted_locations = inlier_points_distorted.Location;
    reference_locations = inlier_points_reference.Location;
    transformed_points = transformPointsForward(tform, distorted_locations);

    % 计算重投影误差
    point_errors = sqrt(sum((transformed_points - reference_locations).^2, 2));

    % 计算统计指标
    mean_error = mean(point_errors);
    median_error = median(point_errors);
    std_error = std(point_errors);
    rmse_error = sqrt(mean(point_errors.^2));
    max_error = max(point_errors);  % 添加缺失的字段
    min_error = min(point_errors);  % 添加缺失的字段
    inlier_ratio = length(inlier_idx) / size(matched_points_distorted, 1);

    % 计算匹配点分布均匀性
    x_coords = reference_locations(:,1);
    y_coords = reference_locations(:,2);
    x_std = std(x_coords);
    y_std = std(y_coords);
    reference_gray_double = double(reference_gray(:));
    distribution_score = (x_std + y_std) / (std(reference_gray_double) + eps);

    % 保存统计信息
    stats.mean_error = mean_error;
    stats.median_error = median_error;
    stats.std_error = std_error;
    stats.rmse_error = rmse_error;
    stats.max_error = max_error;  % 添加缺失的字段
    stats.min_error = min_error;  % 添加缺失的字段
    stats.inlier_ratio = inlier_ratio;
    stats.all_errors = point_errors;
    stats.num_matches = size(matched_points_distorted, 1);
    stats.num_inliers = length(inlier_idx);
    stats.distribution_score = distribution_score;
    stats.method_name = 'SURF';
    
    % 保存匹配点信息用于可视化
    stats.matched_points_distorted = matched_points_distorted;
    stats.matched_points_reference = matched_points_reference;
    stats.inlier_points_distorted = inlier_points_distorted;
    stats.inlier_points_reference = inlier_points_reference;
    stats.points_distorted = points_distorted;
    stats.points_reference = points_reference;

    fprintf('SURF图像纠正完成！找到%d个内点匹配\n', length(inlier_idx));
    fprintf('平均误差: %.2f 像素, 匹配成功率: %.1f%%\n', mean_error, inlier_ratio*100);

    %% 4. 显示校正结果图像
    show_surf_correction_results(distorted_img, reference_img, corrected_img, stats);
end

function show_surf_correction_results(distorted_img, reference_img, corrected_img, stats)
    % 显示SURF校正结果
    
    % 创建主结果显示窗口
    figure('Name', '王紫航-SURF图像校正结果');
    
    % 子图1: 原始扭曲图像 + SURF特征点
    subplot(2, 4, 1);
    imshow(distorted_img); hold on;
    if isfield(stats, 'points_distorted') && ~isempty(stats.points_distorted)
        plot(stats.points_distorted.selectStrongest(50));
    end
    title('原始扭曲图像 + SURF特征点', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 子图2: 参考图像 + SURF特征点
    subplot(2, 4, 2);
    imshow(reference_img); hold on;
    if isfield(stats, 'points_reference') && ~isempty(stats.points_reference)
        plot(stats.points_reference.selectStrongest(50));
    end
    title('参考图像 + SURF特征点', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 子图3: 校正后图像
    subplot(2, 4, 3);
    imshow(corrected_img);
    title('SURF校正后图像', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 子图4: 并排对比
    subplot(2, 4, 4);
    % 调整尺寸匹配
    ref_resized = imresize(reference_img, [size(corrected_img,1), size(corrected_img,2)]);
    montage({ref_resized, corrected_img}, 'Size', [1, 2]);
    title('参考图像 vs 校正后图像', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 子图5: 特征点匹配结果
    subplot(2, 4, 5);
    if isfield(stats, 'matched_points_distorted') && isfield(stats, 'matched_points_reference')
        showMatchedFeatures(rgb2gray(reference_img), rgb2gray(distorted_img), ...
                           stats.matched_points_reference, stats.matched_points_distorted, 'montage');
        title('所有特征点匹配', 'FontSize', 10);
    else
        text(0.5, 0.5, '匹配点数据不可用', 'HorizontalAlignment', 'center');
        axis off;
    end
    
    % 子图6: 内点匹配结果
    subplot(2, 4, 6);
    if isfield(stats, 'inlier_points_distorted') && isfield(stats, 'inlier_points_reference')
        showMatchedFeatures(rgb2gray(reference_img), rgb2gray(distorted_img), ...
                           stats.inlier_points_reference, stats.inlier_points_distorted, 'montage');
        title('RANSAC内点匹配', 'FontSize', 10);
    else
        text(0.5, 0.5, '内点数据不可用', 'HorizontalAlignment', 'center');
        axis off;
    end
    
    % 子图7: 差异图
    subplot(2, 4, 7);
    if size(reference_img, 3) == 3
        ref_gray = rgb2gray(reference_img);
    else
        ref_gray = reference_img;
    end
    if size(corrected_img, 3) == 3
        cor_gray = rgb2gray(corrected_img);
    else
        cor_gray = corrected_img;
    end
    % 调整尺寸匹配
    ref_gray_resized = imresize(ref_gray, [size(cor_gray,1), size(cor_gray,2)]);
    diff_img = imabsdiff(ref_gray_resized, cor_gray);
    imshow(diff_img, []);
    colorbar;
    title('差异图 (参考-校正)', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 子图8: 统计信息
    subplot(2, 4, 8);
    axis off;
    
    % 质量评价
    if stats.mean_error < 2.0
        quality = '优秀';
        color = 'green';
    elseif stats.mean_error < 5.0
        quality = '良好';
        color = 'blue';
    elseif stats.mean_error < 8.0
        quality = '一般';
        color = 'orange';
    else
        quality = '需要改进';
        color = 'red';
    end
    
    info_text = {
        'SURF校正统计',...
        '============',...
        sprintf('SURF特征点: %d/%d', ...
            length(stats.points_distorted), length(stats.points_reference)),...
        sprintf('匹配点总数: %d', stats.num_matches),...
        sprintf('内点数量: %d', stats.num_inliers),...
        sprintf('匹配成功率: %.1f%%', stats.inlier_ratio * 100),...
        '',...
        '误差统计:',...
        sprintf('平均误差: %.3f 像素', stats.mean_error),...
        sprintf('最大误差: %.3f 像素', stats.max_error),...
        sprintf('标准差: %.3f 像素', stats.std_error),...
        sprintf('分布评分: %.3f', stats.distribution_score),...
        '',...
        '质量评价:',...
        sprintf('%s', quality)
    };
    
    text(0.1, 0.95, info_text, 'FontSize', 9, 'VerticalAlignment', 'top', ...
         'BackgroundColor', [0.95, 0.95, 0.95], 'Color', color);
    
    drawnow;
end