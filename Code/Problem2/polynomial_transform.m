function [registered_img, tform, stats] = polynomial_transform(data_folder)
% 二次多项式变换方法

    fprintf('开始二次多项式变换...\n');
    
    % 读取武汉影像数据
    ref = imread(fullfile(data_folder, '武汉参考影像.png'));
    mov = imread(fullfile(data_folder, '武汉待校正影像.png'));
    
    % 转换为灰度图用于选点
    if size(ref, 3) == 3
        refGray = rgb2gray(ref);
    else
        refGray = ref;
    end
    
    if size(mov, 3) == 3
        movGray = rgb2gray(mov);
    else
        movGray = mov;
    end
    
    fprintf('请选择控制点进行二次多项式变换...\n');
    fprintf('建议选择 >= 10 对控制点以获得更好的精度\n');
    fprintf('控制点应分布均匀，包含图像四角、中心等位置\n');
    
    %% 修复：正确使用cpselect
    fprintf('正在打开 cpselect 界面...\n');
    
    % 使用正确的cpselect调用方式
    [movingPoints, fixedPoints] = cpselect(movGray, refGray, 'Wait', true);
    
    % 检查控制点变量是否存在
    if isempty(movingPoints) || isempty(fixedPoints)
        error('未检测到有效的控制点，请确认已经在 cpselect 中选择并导出了控制点。');
    end
    
    fprintf('成功选择 %d 对控制点\n', size(movingPoints, 1));
    
    % 数据预处理
    movingPoints = double(movingPoints);
    fixedPoints = double(fixedPoints);
    
    valid = all(isfinite(movingPoints), 2) & all(isfinite(fixedPoints), 2);
    movingPoints = movingPoints(valid, :);
    fixedPoints = fixedPoints(valid, :);
    
    [~, ia] = unique(movingPoints, 'rows', 'stable');
    movingPoints = movingPoints(ia, :);
    fixedPoints = fixedPoints(ia, :);
    
    numPts = size(movingPoints, 1);
    fprintf('当前有效控制点个数：%d\n', numPts);
    
    if numPts < 6
        error('有效控制点不足 6 个，无法进行二次多项式变换拟合。');
    end
    
    % 显示控制点分布
    show_control_points(movGray, refGray, movingPoints, fixedPoints, '多项式变换控制点分布');
    
    % 检查控制点分布情况
    fprintf('正在检查控制点分布情况...\n');
    X = [ones(numPts,1), ...
         movingPoints(:,1), movingPoints(:,2), ...
         movingPoints(:,1).^2, ...
         movingPoints(:,1).*movingPoints(:,2), ...
         movingPoints(:,2).^2];

    rX = rank(X);
    fprintf('多项式设计矩阵的秩：%d\n', rX);

    if rX < 6
        error('控制点在几何上接近共线或分布过于退化，无法拟合二次多项式。');
    end
    
    % 拟合二次多项式变换模型
    fprintf('正在拟合二次多项式变换模型...\n');
    order = 2;
    tform = fitgeotrans(movingPoints, fixedPoints, 'polynomial', order);
    
    % 计算变换误差（多项式变换的特殊处理）
    A = tform.A;  % 用于计算x坐标的系数
    B = tform.B;  % 用于计算y坐标的系数
    
    % 构造多项式项 [1, x, y, x^2, x*y, y^2]
    X_poly = [ones(numPts,1), ...
              movingPoints(:,1), movingPoints(:,2), ...
              movingPoints(:,1).^2, ...
              movingPoints(:,1).*movingPoints(:,2), ...
              movingPoints(:,2).^2];
    
    % 计算变换后的坐标
    predicted_x = X_poly * A';
    predicted_y = X_poly * B';
    predicted_points = [predicted_x, predicted_y];
    
    residuals = fixedPoints - predicted_points;
    residual_distances = sqrt(sum(residuals.^2, 2));
    
    % 保存统计信息
    stats.mean_error = mean(residual_distances);
    stats.max_error = max(residual_distances);
    stats.std_error = std(residual_distances);
    stats.all_errors = residual_distances;
    stats.num_points = numPts;
    stats.transform_type = 'polynomial2';
    
    % 计算R²拟合优度
    ss_total_x = sum((fixedPoints(:,1) - mean(fixedPoints(:,1))).^2);
    ss_residual_x = sum(residuals(:,1).^2);
    r_squared_x = 1 - (ss_residual_x / ss_total_x);
    
    ss_total_y = sum((fixedPoints(:,2) - mean(fixedPoints(:,2))).^2);
    ss_residual_y = sum(residuals(:,2).^2);
    r_squared_y = 1 - (ss_residual_y / ss_total_y);
    
    stats.r_squared = (r_squared_x + r_squared_y) / 2;
    
    % 应用几何变换
    Rfixed = imref2d(size(refGray));
    registered_img = imwarp(mov, tform, 'OutputView', Rfixed, 'Interp', 'cubic');
    
    % 显示结果图像
    show_registration_results(mov, ref, registered_img, '多项式变换结果');
    
    fprintf('二次多项式变换完成 - 平均误差: %.4f 像素, R²: %.4f\n', ...
            stats.mean_error, stats.r_squared);
end

% 使用相同的辅助函数（在同一个文件中）
function show_control_points(movGray, refGray, movingPoints, fixedPoints, title_str)
    % 显示控制点分布
    figure('Name', title_str);
    
    subplot(1,2,1);
    imshow(movGray, []); hold on;
    plot(movingPoints(:,1), movingPoints(:,2), 'r*', 'MarkerSize', 8, 'LineWidth', 2);
    for i = 1:size(movingPoints,1)
        text(movingPoints(i,1)+10, movingPoints(i,2)+10, num2str(i), ...
             'Color', 'yellow', 'FontSize', 10, 'FontWeight', 'bold');
    end
    title('待校正影像上的控制点');
    xlabel('X坐标'); ylabel('Y坐标');
    
    subplot(1,2,2);
    imshow(refGray, []); hold on;
    plot(fixedPoints(:,1), fixedPoints(:,2), 'g*', 'MarkerSize', 8, 'LineWidth', 2);
    for i = 1:size(fixedPoints,1)
        text(fixedPoints(i,1)+10, fixedPoints(i,2)+10, num2str(i), ...
             'Color', 'yellow', 'FontSize', 10, 'FontWeight', 'bold');
    end
    title('参考影像上的控制点');
    xlabel('X坐标'); ylabel('Y坐标');
end

function show_registration_results(mov, ref, registered_img, title_str)
    % 显示配准结果
    figure('Name', title_str);
    
    subplot(1,4,1);
    imshow(mov, []);
    title('原始待校正影像', 'FontSize', 12);
    
    subplot(1,4,2);
    imshow(ref, []);
    title('参考影像', 'FontSize', 12);
    
    subplot(1,4,3);
    imshow(registered_img, []);
    title('校正后影像', 'FontSize', 12);
    
    subplot(1,4,4);
    % 调整尺寸匹配后显示差异图
    if size(ref, 3) == 3
        ref_gray = rgb2gray(ref);
    else
        ref_gray = ref;
    end
    if size(registered_img, 3) == 3
        reg_gray = rgb2gray(registered_img);
    else
        reg_gray = registered_img;
    end
    ref_resized = imresize(ref_gray, [size(reg_gray,1), size(reg_gray,2)]);
    diff_img = imabsdiff(ref_resized, reg_gray);
    imshow(diff_img, []);
    title('差异图', 'FontSize', 12);
    colorbar;
    
    drawnow;
end