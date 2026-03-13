function [corrected_image, tform, stats] = interactive_correction(data_folder)
% 基于参考图像的交互式图像纠正（固定读取文件版本）
% data_folder 一般为 '数据'，内部固定读取：
%   扭曲图片.png  作为待纠正图像
%   正常图片.png  作为参考图像

    if nargin < 1 || isempty(data_folder)
        data_folder = '数据';
    end

    close all; clc;
    fprintf('=== - 基于参考图像的图像纠正（固定读取文件） ===\n');

    corrected_image = [];
    tform = [];
    stats = struct();

    try
        % 1) 固定路径读取图像
        [source_image, source_filename, reference_image, reference_filename] = ...
            load_fixed_images(data_folder);

        if isempty(source_image) || isempty(reference_image)
            fprintf('图像读取失败，无法继续纠正。\n');
            stats = make_empty_stats();
            return;
        end

        % 2) 进入交互式纠正流程（选点 + 变换 + 误差）
        [corrected_image, tform, stats] = single_image_rectification_core( ...
            source_image, source_filename, reference_image, reference_filename);

        if isempty(corrected_image)
            fprintf('图像纠正未完成或被取消。\n');
            if ~isfield(stats, 'mean_error')
                stats = make_empty_stats();
            end
        else
            fprintf('图像纠正完成！\n');
        end

    catch ME
        fprintf('交互式纠正过程中发生错误: %s\n', ME.message);
        corrected_image = [];
        tform = [];
        stats = make_empty_stats();
    end
end

%% ================== 固定文件读取 ==================
function [source_image, source_filename, reference_image, reference_filename] = ...
    load_fixed_images(data_folder)

    source_filename    = '扭曲图片.png';   % 待纠正图像
    reference_filename = '正常图片.png';   % 参考图像

    source_path    = fullfile(data_folder, source_filename);
    reference_path = fullfile(data_folder, reference_filename);

    source_image = [];
    reference_image = [];

    % 读取待纠正图像
    if ~exist(source_path, 'file')
        fprintf('错误：找不到待纠正图像文件：%s\n', source_path);
    else
        try
            source_image = imread(source_path);
            if ndims(source_image) == 2
                ch = 1;
            else
                ch = size(source_image, 3);
            end
            fprintf('待纠正图像加载成功: %s (%dx%d 像素, %d 通道)\n', ...
                source_filename, size(source_image, 2), size(source_image, 1), ch);
        catch ME
            fprintf('读取待纠正图像失败: %s\n', ME.message);
            source_image = [];
        end
    end

    % 读取参考图像
    if ~exist(reference_path, 'file')
        fprintf('错误：找不到参考图像文件：%s\n', reference_path);
    else
        try
            reference_image = imread(reference_path);
            if ndims(reference_image) == 2
                ch = 1;
            else
                ch = size(reference_image, 3);
            end
            fprintf('参考图像加载成功: %s (%dx%d 像素, %d 通道)\n', ...
                reference_filename, size(reference_image, 2), size(reference_image, 1), ch);
        catch ME
            fprintf('读取参考图像失败: %s\n', ME.message);
            reference_image = [];
        end
    end
end

%% ================== 主纠正流程（不再选文件，只负责选点 + 变换） ==================
function [corrected_image, tform, stats] = single_image_rectification_core( ...
    source_image, source_filename, reference_image, reference_filename)

    corrected_image = [];
    tform = [];
    stats = struct();

    % 1. 调整图像尺寸以便显示
    [source_image, reference_image] = adjust_image_sizes(source_image, reference_image);

    % 2. 选择变换方法
    [transform_type, min_points] = select_transform_method();
    if isempty(transform_type)
        stats = make_empty_stats();
        return;
    end

    % 3. 在两幅图像上选择对应的控制点
    [sourcePoints, referencePoints] = select_corresponding_points(...
        source_image, reference_image, source_filename, reference_filename, ...
        transform_type, min_points);

    if isempty(sourcePoints)
        fprintf('控制点选择取消。\n');
        stats = make_empty_stats();
        return;
    end

    % 4. 应用变换并显示结果
    [corrected_image, tform, error_stats] = apply_transformation(...
        source_image, reference_image,sourcePoints, referencePoints, transform_type);

    if isempty(corrected_image)
        fprintf('图像纠正失败。\n');
        stats = make_empty_stats();
        return;
    end

    % 5. 整理 stats，兼容 evaluation_auto / 综合评估
    stats = error_stats;
    stats.original_image          = source_image;
    stats.reference_image         = reference_image;
    stats.corrected_image         = corrected_image;
    stats.inlier_points_distorted = sourcePoints;
    stats.inlier_points_reference = referencePoints;
    stats.method_name             = '交互式图像纠正';

    if isfield(error_stats, 'all_errors') && ~isempty(error_stats.all_errors)
        stats.num_points   = numel(error_stats.all_errors);
        stats.max_error    = max(error_stats.all_errors);
        stats.min_error    = min(error_stats.all_errors);
        stats.median_error = median(error_stats.all_errors);
    else
        stats.num_points   = 0;
        stats.max_error    = NaN;
        stats.min_error    = NaN;
        stats.median_error = NaN;
    end
end

%% ================== 空 stats 结构（出错/取消时用） ==================
function s = make_empty_stats()
    s = struct();
    s.mean_error   = NaN;
    s.max_error    = NaN;
    s.min_error    = NaN;
    s.median_error = NaN;
    s.std_error    = NaN;
    s.all_errors   = [];
    s.num_points   = 0;
end

%% ================== 尺寸调整 ==================
function [src_img, ref_img] = adjust_image_sizes(src_img, ref_img)
    % 调整图像尺寸以便显示
    src_size = size(src_img);
    ref_size = size(ref_img);

    fprintf('源图像尺寸: %dx%d\n', src_size(2), src_size(1));
    fprintf('参考图像尺寸: %dx%d\n', ref_size(2), ref_size(1));

    % 调整参考图像尺寸以匹配源图像（保持宽高比）
    scale_factor = min(src_size(1)/ref_size(1), src_size(2)/ref_size(2));
    new_size = round([ref_size(1)*scale_factor, ref_size(2)*scale_factor]);

    ref_img = imresize(ref_img, [new_size(1), new_size(2)]);
end

%% ================== 选择变换方法 ==================
function [transform_type, min_points] = select_transform_method()
    % 选择变换方法
    fprintf('\n请选择变换方法:\n');
    fprintf('1 - 仿射变换 - 旋转/缩放/错切，需要至少3对点\n');
    fprintf('2 - 投影变换 - 透视纠正，需要至少4对点\n');
    fprintf('3 - 二阶多项式 - 复杂变形，需要至少6对点\n');
    fprintf('4 - 三阶多项式 - 更复杂变形，需要至少10对点\n');
    fprintf('5 - 局部加权平均 (LWM) - 平滑变形，需要至少6对点\n');

    choice = input('请输入选择 (1-5): ');

    switch choice
        case 1
            transform_type = 'affine';
            min_points = 3;
        case 2
            transform_type = 'projective';
            min_points = 4;
        case 3
            transform_type = 'polynomial2';
            min_points = 6;
        case 4
            transform_type = 'polynomial3';
            min_points = 10;
        case 5
            transform_type = 'lwm';
            min_points = 6;
        otherwise
            fprintf('无效选择，使用默认的投影变换。\n');
            transform_type = 'projective';
            min_points = 4;
    end

    fprintf('已选择: %s (最少需要 %d 对控制点)\n', transform_type, min_points);
end

function min_points = get_min_points(transform_type)
    % 获取最少需要的控制点数（备用）
    switch transform_type
        case 'affine'
            min_points = 3;
        case 'projective'
            min_points = 4;
        case 'polynomial2'
            min_points = 6;
        case 'polynomial3'
            min_points = 10;
        case 'lwm'
            min_points = 6;
        otherwise
            min_points = 4;
    end
end

%% ================== 控制点选择 ==================
function [sourcePoints, referencePoints] = select_corresponding_points( ...
    source_image, reference_image, source_name, reference_name, transform_type, min_points)

    fprintf('\n=== 控制点选择 ===\n');

    if nargin < 6
        min_points = get_min_points(transform_type);
    end

    fprintf('请在两幅图像上按相同顺序选择对应的控制点\n');
    fprintf('最少需要选择 %d 对控制点\n', min_points);
    fprintf('推荐选择明显的特征点：角点、交叉点、显著特征等\n\n');

    % 第一步：源图像
    fprintf('第一步：在待纠正图像上选择控制点...\n');
    sourcePoints = select_points_interactive(source_image, ...
        sprintf('待纠正图像: %s - 选择控制点', source_name), min_points);

    if isempty(sourcePoints)
        referencePoints = [];
        return;
    end

    n_points = size(sourcePoints, 1);
    fprintf('已在源图像选择 %d 个控制点。\n', n_points);

    % 显示源图像控制点
    figure('Name', '源图像控制点', 'Position', [100, 200, 600, 500]);
    imshow(source_image);
    hold on;
    plot(sourcePoints(:,1), sourcePoints(:,2), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
    for i = 1:n_points
        text(sourcePoints(i,1)+15, sourcePoints(i,2)+15, num2str(i), ...
            'Color', 'red', 'FontSize', 14, 'FontWeight', 'bold');
    end
    title(sprintf('源图像控制点 (%d个点)', n_points), 'FontSize', 12);

    % 第二步：参考图像
    fprintf('\n第二步：在参考图像上选择对应的控制点（按相同顺序）...\n');
    referencePoints = select_points_interactive(reference_image, ...
        sprintf('参考图像: %s - 选择对应的控制点（顺序: 1→%d）', reference_name, n_points), ...
        n_points, n_points);

    if isempty(referencePoints) || size(referencePoints,1) ~= n_points
        fprintf('目标点选择不完整，操作取消。\n');
        sourcePoints = []; 
        referencePoints = [];
        return;
    end

    % 显示对应关系
    show_point_correspondence(source_image, reference_image, sourcePoints, referencePoints);
end

function points = select_points_interactive(image, title_str, min_points, exact_points)
    % 交互选择点
    fig = figure('Position', [200, 200, 800, 600], 'Name', '控制点选择', ...
                'NumberTitle', 'off', 'MenuBar', 'none');
    imshow(image);
    title(title_str, 'FontSize', 12, 'FontWeight', 'bold');

    points = [];
    selected_points = 0;

    if nargin >= 4
        max_points = exact_points;
        subtitle_str = sprintf('需要选择恰好 %d 个点（按 Enter 确认）', exact_points);
    else
        max_points = Inf;
        subtitle_str = sprintf('至少选择 %d 个点，按 Enter 结束', min_points);
    end

    uicontrol('Style', 'text', 'String', subtitle_str, ...
             'Position', [10, 10, 500, 40], ...
             'BackgroundColor', get(fig, 'Color'), ...
             'FontSize', 11, 'HorizontalAlignment', 'left', ...
             'FontWeight', 'bold');

    hold on;

    while selected_points < max_points
        try
            [x, y, button] = ginput(1);

            % Enter 结束
            if isempty(button) || button == 13
                if selected_points >= min_points
                    break;
                else
                    msgbox(sprintf('至少需要选择 %d 个点！', min_points), '提示');
                    continue;
                end
            end

            % 左键添加点
            if button == 1
                selected_points = selected_points + 1;
                points(selected_points, :) = [x, y];

                plot(x, y, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
                text(x + 20, y + 20, num2str(selected_points), ...
                    'Color', 'red', 'FontSize', 14, 'FontWeight', 'bold');

                fprintf('  点 %d: (%.1f, %.1f)\n', selected_points, x, y);
            end

        catch
            break;
        end
    end

    if ~ishandle(fig)
        points = [];
    else
        close(fig);
    end

    if ~isempty(points)
        fprintf('选择完成，共 %d 个点。\n', size(points,1));
    end
end

function show_point_correspondence(source_image, reference_image, sourcePoints, referencePoints)
    % 显示控制点对应关系
    figure('Position', [50, 100, 1200, 500], 'Name', '控制点对应关系');

    % 源图像
    subplot(1, 2, 1);
    imshow(source_image);
    hold on;
    plot(sourcePoints(:,1), sourcePoints(:,2), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
    for i = 1:size(sourcePoints,1)
        text(sourcePoints(i,1)+15, sourcePoints(i,2)+15, num2str(i), ...
            'Color', 'red', 'FontSize', 12, 'FontWeight', 'bold');
    end
    title('待纠正图像控制点', 'FontSize', 14);

    % 参考图像
    subplot(1, 2, 2);
    imshow(reference_image);
    hold on;
    plot(referencePoints(:,1), referencePoints(:,2), 'go', 'MarkerSize', 8, 'LineWidth', 2);
    for i = 1:size(referencePoints,1)
        text(referencePoints(i,1)+15, referencePoints(i,2)+15, num2str(i), ...
            'Color', 'green', 'FontSize', 12, 'FontWeight', 'bold');
    end
    title('参考图像控制点', 'FontSize', 14);

    fprintf('控制点对应关系显示完成。\n');
end

%% ================== 应用变换 ==================

function [corrected_image, tform, error_stats] = apply_transformation(...
    image,ref_image, movingPoints, fixedPoints, transform_type)
    % 应用选择的变换
    
    fprintf('\n=== 应用变换 ===\n');
    
    try
        % 在try块一开始就添加调试
        fprintf('1. 进入try块\n');
        fprintf('2. 检查输入参数...\n');
        
        % 检查所有输入参数
        if isempty(image)
            error('输入图像为空');
        end
        if isempty(movingPoints) || isempty(fixedPoints)
            error('控制点为空');
        end
        if size(movingPoints,1) ~= size(fixedPoints,1)
            error('控制点数量不匹配');
        end
        
        fprintf('3. 输入参数检查通过\n');
        fprintf('4. 开始创建变换对象...\n');
        
        % 根据变换类型创建变换对象
        switch transform_type
            case 'affine'
                fprintf('5. 创建仿射变换...\n');
                tform = fitgeotrans(movingPoints, fixedPoints, 'affine');
                fprintf('应用仿射变换...\n');
                
            case 'projective'
                fprintf('5. 创建投影变换...\n');
                tform = fitgeotrans(movingPoints, fixedPoints, 'projective');
                fprintf('应用投影变换...\n');
                
            case 'polynomial2'
                fprintf('5. 创建二阶多项式变换...\n');
                tform = fitgeotrans(movingPoints, fixedPoints, 'polynomial', 2);
                fprintf('应用二阶多项式变换...\n');
                
            case 'polynomial3'
                fprintf('5. 创建三阶多项式变换...\n');
                tform = fitgeotrans(movingPoints, fixedPoints, 'polynomial', 3);
                fprintf('应用三阶多项式变换...\n');
                
            case 'lwm'
                fprintf('5. 创建LWM变换...\n');
                n = max(6, min(12, round(size(movingPoints,1)/2)));
                tform = fitgeotrans(movingPoints, fixedPoints, 'lwm', n);
                fprintf('应用局部加权平均变换 (邻域点数: %d)...\n', n);
        end
        
        fprintf('6. 变换对象创建成功\n');
        fprintf('7. 开始设置输出视图...\n');
        
        % 最简单的输出尺寸设置
        output_size = [size(ref_image, 1), size(ref_image, 2)];
        fprintf('8. 输出尺寸设置为: [%d, %d]\n', output_size(1), output_size(2));
        
        % 检查输出尺寸是否为整数
        if any(mod(output_size, 1) ~= 0)
            fprintf('警告: 输出尺寸不是整数，进行取整\n');
            output_size = round(output_size);
        end
        
        % 确保输出尺寸为正数
        output_size = max(1, output_size);
        
        fprintf('9. 创建输出视图对象...\n');
        
        % 创建输出视图
        output_view = imref2d(output_size);
        
        fprintf('10. 输出视图创建成功\n');
        fprintf('11. 开始应用imwarp变换...\n');
        
        % 应用变换
        corrected_image = imwarp(image, tform, 'OutputView', output_view);
        
        fprintf('12. imwarp变换完成\n');
        
        % 计算变换误差
        error_stats = calculate_transformation_error_compatible(tform, movingPoints, fixedPoints, transform_type);
        
        fprintf('变换成功完成！\n');
        
    catch ME
        fprintf('变换失败: %s\n', ME.message);
        fprintf('错误堆栈信息:\n');
        for i = 1:length(ME.stack)
            fprintf('  %s (第%d行)\n', ME.stack(i).name, ME.stack(i).line);
        end
        
        % 检查工作区变量
        fprintf('\n当前工作区变量状态:\n');
        if exist('output_size', 'var')
            fprintf('  output_size: %s\n', mat2str(output_size));
            fprintf('  output_size类型: %s\n', class(output_size));
        else
            fprintf('  output_size: 未定义\n');
        end
        
        if exist('output_view', 'var')
            fprintf('  output_view: 已定义\n');
        else
            fprintf('  output_view: 未定义\n');
        end
        
        corrected_image = [];
        tform = [];
        error_stats = [];
        return;
    end
    
    % 显示结果对比
    show_transformation_results(image, corrected_image, movingPoints, fixedPoints, error_stats);
end


%% ================== 误差计算 ==================
function error_stats = calculate_transformation_error_compatible(tform, movingPoints, fixedPoints, transform_type)
    error_stats = struct();

    try
        fprintf('正在计算变换误差...\n');
        fprintf('变换类型: %s\n', transform_type);
        fprintf('变换对象类型: %s\n', class(tform));

        try
            fprintf('尝试标准 transformPointsForward 方法...\n');
            transformed_points = transformPointsForward(tform, movingPoints);
            fprintf('标准方法成功\n');
        catch ME1
            fprintf('标准方法失败: %s\n', ME1.message);

            if strcmp(transform_type, 'polynomial2') || strcmp(transform_type, 'polynomial3')
                fprintf('尝试手动多项式变换计算...\n');
                transformed_points = transform_points_polynomial(movingPoints, tform);
            elseif strcmp(transform_type, 'lwm')
                fprintf('尝试 LWM 变换手动计算...\n');
                transformed_points = transform_points_lwm(movingPoints, tform, fixedPoints);
            else
                fprintf('使用原始点作为变换后点（降级处理）\n');
                transformed_points = movingPoints;
            end
        end

        errors = sqrt(sum((transformed_points - fixedPoints).^2, 2));

        error_stats.mean_error   = mean(errors);
        error_stats.max_error    = max(errors);
        error_stats.min_error    = min(errors);
        error_stats.median_error = median(errors);
        error_stats.std_error    = std(errors);
        error_stats.all_errors   = errors;
        error_stats.num_points   = numel(errors);
        error_stats.transformed_points = transformed_points;
        error_stats.success      = true;

        fprintf('变换误差统计:\n');
        fprintf('• 平均误差: %.3f 像素\n', error_stats.mean_error);
        fprintf('• 最大误差: %.3f 像素\n', error_stats.max_error);
        fprintf('• 误差标准差: %.3f 像素\n', error_stats.std_error);

    catch ME
        fprintf('误差计算失败: %s\n', ME.message);
        disp(ME.getReport());

        n_points = size(movingPoints, 1);
        error_stats.mean_error   = NaN;
        error_stats.max_error    = NaN;
        error_stats.min_error    = NaN;
        error_stats.median_error = NaN;
        error_stats.std_error    = NaN;
        error_stats.all_errors   = NaN(n_points, 1);
        error_stats.transformed_points = NaN(n_points, 2);
        error_stats.num_points   = n_points;
        error_stats.success      = false;
        error_stats.error_message = ME.message;
    end
end

function transformed_points = transform_points_lwm(movingPoints, tform, fixedPoints)
    fprintf('开始 LWM 变换手动计算...\n');

    try
        if isprop(tform, 'A')
            A = tform.A;
            fprintf('找到 A 属性，长度: %d\n', length(A));
            n_points = size(movingPoints, 1);
            transformed_points = zeros(n_points, 2);
            for i = 1:n_points
                x = movingPoints(i,1);
                y = movingPoints(i,2);
                if length(A) >= 6
                    transformed_points(i,1) = A(1) + A(2)*x + A(3)*y;
                    transformed_points(i,2) = A(4) + A(5)*x + A(6)*y;
                else
                    transformed_points(i,:) = [x, y];
                end
            end
        elseif isprop(tform, 'T')
            T = tform.T;
            fprintf('找到 T 矩阵，尺寸: %dx%d\n', size(T,1), size(T,2));
            n_points = size(movingPoints, 1);
            homogeneous_points = [movingPoints, ones(n_points, 1)];
            transformed_homogeneous = (T * homogeneous_points')';
            transformed_points = transformed_homogeneous(:,1:2) ./ transformed_homogeneous(:,3);
        else
            fprintf('使用基于控制点的插值方法...\n');
            transformed_points = interpolate_points_lwm(movingPoints, fixedPoints);
        end

        fprintf('LWM 变换计算完成\n');

    catch ME
        fprintf('LWM 变换手动计算失败: %s\n', ME.message);
        transformed_points = movingPoints;
    end
end

function transformed_points = interpolate_points_lwm(movingPoints, fixedPoints)
    n_points = size(movingPoints, 1);
    transformed_points = zeros(n_points, 2);

    for i = 1:n_points
        distances = sqrt(sum((movingPoints - movingPoints(i,:)).^2, 2));
        distances(i) = Inf;
        [~, idx] = sort(distances);
        nearest_idx = idx(1:min(3, length(idx)));

        if length(nearest_idx) >= 2
            weights = 1 ./ (distances(nearest_idx) + eps);
            weights = weights / sum(weights);
            transformed_points(i,1) = sum(fixedPoints(nearest_idx,1) .* weights);
            transformed_points(i,2) = sum(fixedPoints(nearest_idx,2) .* weights);
        else
            transformed_points(i,:) = mean(fixedPoints, 1);
        end
    end
end

function transformed_points = transform_points_polynomial(points, tform)
    x = points(:,1);
    y = points(:,2);

    try
        if isprop(tform, 'A')
            A = tform.A;
        elseif isprop(tform, 'Coefficients')
            A = tform.Coefficients;
        elseif isprop(tform, 'T')
            A = tform.T;
        else
            transformed_points = transformPointsForward(tform, points);
            return;
        end

        if length(A) == 12
            x_transformed = A(1) + A(2)*x + A(3)*y + A(4)*x.*y + A(5)*x.^2 + A(6)*y.^2;
            y_transformed = A(7) + A(8)*x + A(9)*y + A(10)*x.*y + A(11)*x.^2 + A(12)*y.^2;
        elseif length(A) == 20
            x_transformed = A(1) + A(2)*x + A(3)*y + A(4)*x.*y + A(5)*x.^2 + A(6)*y.^2 + ...
                           A(7)*x.^2.*y + A(8)*x.*y.^2 + A(9)*x.^3 + A(10)*y.^3;
            y_transformed = A(11) + A(12)*x + A(13)*y + A(14)*x.*y + A(15)*x.^2 + A(16)*y.^2 + ...
                           A(17)*x.^2.*y + A(18)*x.*y.^2 + A(19)*x.^3 + A(20)*y.^3;
        else
            transformed_points = transformPointsForward(tform, points);
            return;
        end

        transformed_points = [x_transformed, y_transformed];

    catch ME
        fprintf('多项式变换计算失败: %s\n', ME.message);
        fprintf('尝试使用标准变换方法...\n');
        try
            transformed_points = transformPointsForward(tform, points);
        catch
            transformed_points = points;
            fprintf('所有变换方法都失败，使用原始点。\n');
        end
    end
end

%% ================== 结果显示 ==================
function show_transformation_results(original, corrected, movingPoints, fixedPoints, error_stats)
    figure('Position', [50, 50, 1400, 800], 'Name', '图像纠正结果对比');

    % 原始图像
    subplot(2, 3, 1);
    imshow(original);
    hold on;
    plot(movingPoints(:,1), movingPoints(:,2), 'ro', 'MarkerSize', 6, 'LineWidth', 2);
    title('待纠正图像（含控制点）', 'FontSize', 12);

    % 纠正后图像
    subplot(2, 3, 2);
    imshow(corrected);
    if isfield(error_stats, 'transformed_points') && ~any(isnan(error_stats.transformed_points(:)))
        hold on;
        plot(error_stats.transformed_points(:,1), error_stats.transformed_points(:,2), ...
            'go', 'MarkerSize', 6, 'LineWidth', 2);
    end
    title('纠正后图像', 'FontSize', 12);

    % 并排对比
    subplot(2, 3, 3);
    if size(original, 1) == size(corrected, 1) && size(original, 2) == size(corrected, 2)
        montage({original, corrected}, 'Size', [1, 2]);
    else
        corrected_resized = imresize(corrected, [size(original,1), size(original,2)]);
        montage({original, corrected_resized}, 'Size', [1, 2]);
    end
    title('对比: 原始 (左) vs 纠正后 (右)', 'FontSize', 12);

    % 误差分布
    subplot(2, 3, 4);
    if isfield(error_stats, 'all_errors') && ~any(isnan(error_stats.all_errors))
        bar(error_stats.all_errors);
        xlabel('控制点编号');
        ylabel('误差 (像素)');
        title('各控制点变换误差', 'FontSize', 12);
        grid on;
    else
        text(0.5, 0.5, '误差数据不可用', 'HorizontalAlignment', 'center');
        axis off;
    end

    % 控制点映射关系
    subplot(2, 3, 5);
    if isfield(error_stats, 'transformed_points') && ~any(isnan(error_stats.transformed_points(:)))
        plot(movingPoints(:,1), movingPoints(:,2), 'ro-', 'LineWidth', 2); hold on;
        plot(error_stats.transformed_points(:,1), error_stats.transformed_points(:,2), ...
             'gx-', 'LineWidth', 2);
        plot(fixedPoints(:,1), fixedPoints(:,2), 'b+-', 'LineWidth', 2);
        legend('源点', '变换后点', '目标点', 'Location', 'best');
        title('控制点映射关系', 'FontSize', 12);
        grid on;
    else
        text(0.5, 0.5, '映射数据不可用', 'HorizontalAlignment', 'center');
        axis off;
    end

    % 统计信息
    subplot(2, 3, 6);
    axis off;
    text(0.1, 0.9, '变换质量统计:', 'FontSize', 14, 'FontWeight', 'bold');

    if isfield(error_stats, 'mean_error') && ~isnan(error_stats.mean_error)
        text(0.1, 0.7, sprintf('平均误差: %.3f 像素', error_stats.mean_error), 'FontSize', 12);
        text(0.1, 0.6, sprintf('最大误差: %.3f 像素', error_stats.max_error), 'FontSize', 12);
        text(0.1, 0.5, sprintf('误差标准差: %.3f 像素', error_stats.std_error), 'FontSize', 12);
        if isfield(error_stats, 'all_errors')
            text(0.1, 0.4, sprintf('控制点数量: %d 对', length(error_stats.all_errors)), 'FontSize', 12);
        end

        if error_stats.mean_error < 2.0
            quality_text = '质量评价: 优秀 ';
            color = 'green';
        elseif error_stats.mean_error < 5.0
            quality_text = '质量评价: 良好 ';
            color = 'blue';
        else
            quality_text = '质量评价: 需改进 ';
            color = 'red';
        end
    else
        text(0.1, 0.7, '误差统计不可用', 'FontSize', 12, 'Color', 'red');
        quality_text = '质量评价: 未知';
        color = 'black';
    end
    text(0.1, 0.2, quality_text, 'FontSize', 12, 'Color', color);
end