function run_methods1(data_folder)

    
    % 读取武汉影像数据
    fixed_img_file = '武汉参考影像.png';
    moving_img_file = '武汉待校正影像.png';
    
    fprintf('读取图像...\n');
    fixed_img = imread(fullfile(data_folder, fixed_img_file));
    moving_img = imread(fullfile(data_folder, moving_img_file));
    
    % 转换为灰度图像
    if size(fixed_img, 3) == 3
        fixed_gray = rgb2gray(fixed_img);
    else
        fixed_gray = fixed_img;
    end
    
    if size(moving_img, 3) == 3
        moving_gray = rgb2gray(moving_img);
    else
        moving_gray = moving_img;
    end
    
    fprintf('图像尺寸 - 参考影像: %s, 待校正影像: %s\n', ...
        mat2str(size(fixed_img)), mat2str(size(moving_img)));
    
    % 方法1: 手动控制点投影变换
    fprintf('\n--- 方法1: 手动控制点投影变换 ---\n');
    try
        [registered_img, tform, error_stats, control_points] = ...
            manual_projective(moving_img, fixed_img, moving_gray, fixed_gray);
        
        % 修复：传递所有需要的参数
        evaluation_manual(error_stats, control_points, '手动投影变换', registered_img, fixed_img, moving_img);
    catch ME
        fprintf('方法1执行失败: %s\n', ME.message);
    end
    
    % 方法2: 自动SIFT特征匹配
    fprintf('\n--- 方法2: 自动SIFT特征匹配 ---\n');
    try
        [registered_img_auto, tform_auto, error_stats_auto, feature_points] = ...
            auto_sift(moving_img, fixed_img, moving_gray, fixed_gray);
        
        % 修复：传递所有需要的参数
        evaluation_manual(error_stats_auto, feature_points, '自动SIFT匹配', registered_img_auto, fixed_img, moving_img);
    catch ME
        fprintf('方法2执行失败: %s\n', ME.message);
        fprintf('建议检查Computer Vision Toolbox是否安装，或者图像特征是否明显\n');
    end
    
    fprintf('\n方法执行完毕！\n');
end