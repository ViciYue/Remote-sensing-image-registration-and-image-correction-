function run_comprehensive_evaluation(data_folder)
    % 运行所有方法的综合对比评估
    
    fprintf('\n=== 综合对比评估 ===\n');
    
    results = struct();
    
    fprintf('正在运行所有方法进行对比分析...\n');
    
    % 运行方法集1
    try
        fprintf('运行刘雨彤方法...\n');
        fixed_img = imread(fullfile(data_folder, '武汉参考影像.png'));
        moving_img = imread(fullfile(data_folder, '武汉待校正影像.png'));
        
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
        
        [~, ~, results.manual] = manual_projective(moving_img, fixed_img, moving_gray, fixed_gray);
        [~, ~, results.auto] = auto_sift(moving_img, fixed_img, moving_gray, fixed_gray);
        fprintf('方法完成\n');
    catch ME
        fprintf('方法评估失败: %s\n', ME.message);
    end
    
    % 运行赵英健方法
    try
        fprintf('运行方法集2...\n');
        [~, ~, results.affine] = affine_transform(data_folder);
        [~, ~, results.poly] = polynomial_transform(data_folder);
        fprintf('方法完成\n');
    catch ME
        fprintf('赵英健方法评估失败: %s\n', ME.message);
    end
    
    % 运行王紫航方法
    try
        fprintf('运行方法集3...\n');
        [~, ~, results.sift] = sift_correction(data_folder);
        [~, ~, results.surf] = surf_correction(data_folder);
        fprintf('方法完成\n');
    catch ME
        fprintf('方法评估失败: %s\n', ME.message);
    end
    
    % 运行徐佳琪方法
    try
        fprintf('运行方法集4...\n');
        [~, ~, results.interactive] = interactive_correction(data_folder);
        fprintf('方法完成\n');
    catch ME
        fprintf('方法评估失败: %s\n', ME.message);
    end
    
    % 执行综合对比
    compare_methods(results);
end