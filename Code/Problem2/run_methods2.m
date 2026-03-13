function run_methods2(data_folder)


    
    % 读取图像
    fixed_img = imread(fullfile(data_folder, '武汉参考影像.png'));
    moving_img = imread(fullfile(data_folder, '武汉待校正影像.png'));
    
    % 方法1: 仿射变换
    fprintf('\n--- 方法1: 交互式仿射变换 ---\n');
    try
        [result1, tform1, stats1] = affine_transform(data_folder);
        evaluation_manual(stats1, [], '仿射变换', result1, fixed_img, moving_img);
    catch ME
        fprintf('方法1执行失败: %s\n', ME.message);
    end
    
    % 方法2: 二次多项式变换
    fprintf('\n--- 方法2: 二次多项式变换 ---\n');
    try
        [result2, tform2, stats2] = polynomial_transform(data_folder);
        evaluation_manual(stats2, [], '二次多项式变换', result2, fixed_img, moving_img);
    catch ME
        fprintf('方法2执行失败: %s\n', ME.message);
    end
    
    fprintf('执行完毕！\n');
end