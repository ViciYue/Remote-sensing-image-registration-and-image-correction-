function [registered_img, tform, error_stats, control_points] = ...
         manual_projective(moving_img, fixed_img, moving_gray, fixed_gray)
% 基于手动控制点的投影变换几何校正

    fprintf('开始手动控制点投影变换...\n');
    
    %% 显示选点说明
    fprintf('请仔细对照两幅图像，选择明显的、相同的特征点\n');
    fprintf('选点顺序：\n');
    fprintf('1. 先在左侧"待校正影像"上选点\n');
    fprintf('2. 然后在右侧"参考影像"上选对应点\n');
    fprintf('3. 至少选择4对点，推荐选择6-8对点，均匀分布在图像四周和中心\n');
    fprintf('4. 选完后按回车键结束\n\n');
    
    %% 手动选择控制点
    [moving_points, fixed_points] = cpselect(moving_gray, fixed_gray, 'Wait', true);

    % 检查选点数量
    if size(moving_points, 1) < 4
        error('至少需要选择4对控制点！当前只选了 %d 对', size(moving_points, 1));
    end
    
    fprintf('成功选择 %d 对控制点\n', size(moving_points, 1));
    
    %% 保存控制点信息
    control_points.moving_points = moving_points;
    control_points.fixed_points = fixed_points;
    control_points.num_points = size(moving_points, 1);
    
    %% 尝试不同的变换模型
    fprintf('计算变换矩阵...\n');
    
    % 按稳定性顺序尝试变换模型
    try
        tform = fitgeotrans(moving_points, fixed_points, 'similarity');
        transform_type = '相似变换';
    catch
        try
            tform = fitgeotrans(moving_points, fixed_points, 'affine');
            transform_type = '仿射变换';
        catch
            try
                tform = fitgeotrans(moving_points, fixed_points, 'projective');
                transform_type = '投影变换';
            catch ME
                error('所有变换模型都失败: %s', ME.message);
            end
        end
    end
    
    %% 应用几何变换
    output_view = imref2d(size(fixed_gray));
    registered_img = imwarp(moving_img, tform, 'OutputView', output_view);
    
    %% 计算配准误差
    transformed_points = transformPointsForward(tform, moving_points);
    errors = sqrt(sum((transformed_points - fixed_points).^2, 2));
    
    error_stats.mean_error = mean(errors);
    error_stats.max_error = max(errors);
    error_stats.min_error = min(errors);
    error_stats.std_error = std(errors);
    error_stats.all_errors = errors;
    error_stats.transform_type = transform_type;
    
    fprintf('手动控制点配准完成 - 平均误差: %.2f 像素，使用 %s\n', ...
            error_stats.mean_error, transform_type);
    
    