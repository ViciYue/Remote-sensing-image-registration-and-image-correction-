function evaluation_manual(error_stats, feature_info, method_name, registered_img, fixed_img, moving_img)
% 手动方法的统一评估函数
% 新增参数：registered_img, fixed_img, moving_img 用于图像显示
    
    fprintf('\n=== %s 评估结果 ===\n', method_name);
    
    % 基本误差统计
    fprintf('误差统计:\n');
    fprintf('• 平均误差: %.4f 像素\n', error_stats.mean_error);
    fprintf('• 最大误差: %.4f 像素\n', error_stats.max_error);
    fprintf('• 误差标准差: %.4f 像素\n', error_stats.std_error);
    
    if isfield(error_stats, 'min_error')
        fprintf('• 最小误差: %.4f 像素\n', error_stats.min_error);
    end
    
    if isfield(error_stats, 'transform_type')
        fprintf('• 使用变换: %s\n', error_stats.transform_type);
    end
    
    if isfield(error_stats, 'r_squared')
        fprintf('• R²拟合优度: %.4f\n', error_stats.r_squared);
    end
    
    if isfield(error_stats, 'num_points')
        fprintf('• 控制点数量: %d 个\n', error_stats.num_points);
    end
    
    % 控制点信息显示
    if ~isempty(feature_info)
        if isfield(feature_info, 'num_points')
            fprintf('• 控制点数量: %d 对\n', feature_info.num_points);
        elseif isfield(feature_info, 'num_matches')
            fprintf('• 匹配点数量: %d 对\n', feature_info.num_matches);
        elseif isfield(feature_info, 'num_inliers')
            fprintf('• 内点数量: %d 对\n', feature_info.num_inliers);
        end
    end
    
    % 质量评级
    fprintf('\n质量评级:\n');
    if error_stats.mean_error < 1.0
        if isfield(error_stats, 'r_squared') && error_stats.r_squared > 0.95
            quality_grade = '优秀 ★★★';
        else
            quality_grade = '优秀 ★★';
        end
    elseif error_stats.mean_error < 2.0
        if isfield(error_stats, 'r_squared') && error_stats.r_squared > 0.90
            quality_grade = '良好 ★★';
        else
            quality_grade = '良好 ★';
        end
    elseif error_stats.mean_error < 3.0
        if isfield(error_stats, 'r_squared') && error_stats.r_squared > 0.80
            quality_grade = '一般 ★';
        else
            quality_grade = '一般';
        end
    else
        quality_grade = '需要改进';
    end
    
    fprintf('• 总体评价: %s\n', quality_grade);
    
    % 可视化结果 - 创建两个图：一个显示图像，一个显示误差分析
    % 图1: 图像对比显示
    figure('Name', sprintf('%s - 图像校正结果', method_name));
    
    % 子图1: 原始待校正图像
    subplot(2, 4, 1);
    imshow(moving_img);
    title('原始待校正图像', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 子图2: 参考图像
    subplot(2, 4, 2);
    imshow(fixed_img);
    title('参考图像', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 子图3: 校正后图像
    subplot(2, 4, 3);
    imshow(registered_img);
    title('校正后图像', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 子图4: 并排对比
    subplot(2, 4, 4);
    % 调整图像尺寸以便并排显示
    fixed_resized = imresize(fixed_img, [size(registered_img,1), size(registered_img,2)]);
    montage({fixed_resized, registered_img}, 'Size', [1, 2]);
    title('参考图像 vs 校正后图像', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 子图5: 差异图
    subplot(2, 4, 5);
    if size(fixed_img, 3) == 3
        fixed_gray = rgb2gray(fixed_img);
    else
        fixed_gray = fixed_img;
    end
    if size(registered_img, 3) == 3
        registered_gray = rgb2gray(registered_img);
    else
        registered_gray = registered_img;
    end
    % 调整尺寸匹配
    fixed_gray_resized = imresize(fixed_gray, [size(registered_gray,1), size(registered_gray,2)]);
    diff_img = imabsdiff(fixed_gray_resized, registered_gray);
    imshow(diff_img, []);
    colorbar;
    title('差异图 (参考-校正)', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 子图6: 叠加显示
    subplot(2, 4, 6);
    fixed_resized_rgb = imresize(fixed_img, [size(registered_img,1), size(registered_img,2)]);
    overlay_img = imfuse(fixed_resized_rgb, registered_img, 'blend', 'Scaling', 'joint');
    imshow(overlay_img);
    title('图像叠加显示', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 子图7: 质量总结
    subplot(2, 4, 7);
    axis off;
    text(0.1, 0.9, '校正质量总结', 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'blue');
    text(0.1, 0.7, sprintf('评级: %s', quality_grade), 'FontSize', 12, 'FontWeight', 'bold');
    text(0.1, 0.6, sprintf('平均误差: %.3f 像素', error_stats.mean_error), 'FontSize', 11);
    if isfield(error_stats, 'transform_type')
        text(0.1, 0.5, sprintf('变换类型: %s', error_stats.transform_type), 'FontSize', 11);
    end
    if isfield(error_stats, 'num_points')
        text(0.1, 0.4, sprintf('控制点: %d 个', error_stats.num_points), 'FontSize', 11);
    end
    
    % 子图8: 建议
    subplot(2, 4, 8);
    axis off;
    if error_stats.mean_error < 2.0
        advice = {'校正效果:', '• 质量优秀', '• 图像对齐良好', '• 可实际应用'};
        color = 'green';
    elseif error_stats.mean_error < 5.0
        advice = {'校正效果:', '• 质量良好', '• 基本对齐', '• 可优化改进'};
        color = 'blue';
    else
        advice = {'校正效果:', '• 需要改进', '• 检查控制点', '• 调整参数'};
        color = 'red';
    end
    text(0.1, 0.8, advice, 'FontSize', 11, 'VerticalAlignment', 'top', 'Color', color);
    
    % 图2: 误差分析（单独窗口）
    figure('Name', sprintf('%s - 误差分析', method_name));
    
    if ~isempty(error_stats.all_errors)
        % 子图1: 误差分布曲线
        subplot(2, 3, 1);
        n_errors = length(error_stats.all_errors);
        plot(1:n_errors, error_stats.all_errors, 'bo-', 'LineWidth', 2, 'MarkerSize', 6);
        hold on;
        plot([1, n_errors], [error_stats.mean_error, error_stats.mean_error], 'r--', 'LineWidth', 2);
        xlabel('点编号');
        ylabel('误差 (像素)');
        title('各点误差分布');
        legend('点误差', '平均误差', 'Location', 'best');
        grid on;
        
        % 子图2: 误差直方图
        subplot(2, 3, 2);
        histogram(error_stats.all_errors, 10, 'FaceColor', 'blue', 'FaceAlpha', 0.7);
        xlabel('误差 (像素)');
        ylabel('频数');
        title('误差分布直方图');
        grid on;
        
        % 子图3: 替代箱线图 - 使用误差统计图
        subplot(2, 3, 3);
        errors_sorted = sort(error_stats.all_errors);
        plot(errors_sorted, 'r-', 'LineWidth', 2);
        hold on;
        plot([1, n_errors], [error_stats.mean_error, error_stats.mean_error], 'b--', 'LineWidth', 2);
        plot([1, n_errors], [error_stats.mean_error + error_stats.std_error, error_stats.mean_error + error_stats.std_error], 'g--', 'LineWidth', 1);
        plot([1, n_errors], [error_stats.mean_error - error_stats.std_error, error_stats.mean_error - error_stats.std_error], 'g--', 'LineWidth', 1);
        xlabel('排序后的点');
        ylabel('误差 (像素)');
        title('误差排序分布');
        legend('排序误差', '平均值', '±标准差', 'Location', 'best');
        grid on;
    end
    
    % 子图4: 误差统计表格
    subplot(2, 3, 4);
    axis off;
    stats_text = {
        '误差统计',...
        '========',...
        sprintf('平均值: %.4f', error_stats.mean_error),...
        sprintf('最大值: %.4f', error_stats.max_error),...
        sprintf('标准差: %.4f', error_stats.std_error)
    };
    if isfield(error_stats, 'min_error')
        stats_text{end+1} = sprintf('最小值: %.4f', error_stats.min_error);
    end
    text(0.1, 0.8, stats_text, 'FontSize', 12, 'VerticalAlignment', 'top');
    
    % 子图5: 控制点信息
    subplot(2, 3, 5);
    axis off;
    if ~isempty(feature_info)
        points_text = {'控制点信息', '=========='};
        if isfield(feature_info, 'num_points')
            points_text{end+1} = sprintf('控制点: %d 对', feature_info.num_points);
        end
        if isfield(feature_info, 'num_matches')
            points_text{end+1} = sprintf('匹配点: %d 对', feature_info.num_matches);
        end
        if isfield(feature_info, 'num_inliers')
            points_text{end+1} = sprintf('内点: %d 对', feature_info.num_inliers);
        end
        text(0.1, 0.8, points_text, 'FontSize', 12, 'VerticalAlignment', 'top');
    end
    
    % 子图6: 详细建议
    subplot(2, 3, 6);
    axis off;
    if error_stats.mean_error > 5.0
        advice = {'改进建议:', '• 重新选择控制点', '• 增加控制点数量', '• 检查图像质量', '• 尝试其他变换模型'};
    elseif error_stats.mean_error > 2.0
        advice = {'改进建议:', '• 优化控制点分布', '• 验证点对精度', '• 调整变换参数'};
    else
        advice = {'当前状态:', '• 精度优秀', '• 控制点选择良好', '• 变换模型合适'};
    end
    text(0.1, 0.8, advice, 'FontSize', 11, 'VerticalAlignment', 'top', 'Color', 'green');
    
    fprintf('\n评估完成！已显示校正结果图像。\n');
end