function evaluation_auto(stats, method_name)
% 自动方法的统一评估函数
    
    fprintf('\n=== %s 评估结果 ===\n', method_name);
    
    % 确保所有必需的字段都存在
    if ~isfield(stats, 'mean_error')
        fprintf('错误: 缺少必需的统计字段\n');
        return;
    end
    
    % 基本误差统计
    fprintf('误差统计:\n');
    fprintf('• 平均误差: %.4f 像素\n', stats.mean_error);
    
    % 检查并显示可选字段
    if isfield(stats, 'max_error')
        fprintf('• 最大误差: %.4f 像素\n', stats.max_error);
    else
        fprintf('• 最大误差: 数据不可用\n');
    end
    
    if isfield(stats, 'std_error')
        fprintf('• 误差标准差: %.4f 像素\n', stats.std_error);
    else
        fprintf('• 误差标准差: 数据不可用\n');
    end
    
    if isfield(stats, 'median_error')
        fprintf('• 中位数误差: %.4f 像素\n', stats.median_error);
    end
    
    if isfield(stats, 'rmse_error')
        fprintf('• RMSE误差: %.4f 像素\n', stats.rmse_error);
    end
    
    % 匹配点信息
    if isfield(stats, 'num_matches')
        fprintf('• 总匹配点: %d 个\n', stats.num_matches);
    end
    
    if isfield(stats, 'num_inliers')
        fprintf('• 内点数量: %d 个\n', stats.num_inliers);
    end
    
    if isfield(stats, 'inlier_ratio')
        fprintf('• 匹配成功率: %.1f%%\n', stats.inlier_ratio * 100);
    end
    
    if isfield(stats, 'distribution_score')
        fprintf('• 分布均匀性: %.3f\n', stats.distribution_score);
    end
    
    if isfield(stats, 'transform_type')
        fprintf('• 变换类型: %s\n', stats.transform_type);
    end
    
    % 质量评级
    fprintf('\n质量评级:\n');
    if stats.mean_error < 2.0
        if isfield(stats, 'inlier_ratio') && stats.inlier_ratio > 0.7
            quality_grade = '优秀 ★★★';
        else
            quality_grade = '优秀 ★★';
        end
    elseif stats.mean_error < 5.0
        if isfield(stats, 'inlier_ratio') && stats.inlier_ratio > 0.5
            quality_grade = '良好 ★★';
        else
            quality_grade = '良好 ★';
        end
    elseif stats.mean_error < 8.0
        quality_grade = '一般 ★';
    else
        quality_grade = '需要改进';
    end
    
    fprintf('• 总体评价: %s\n', quality_grade);
    
    % 可视化分析
    figure('Name', sprintf('%s - 详细分析', method_name));
    
    % 子图1: 误差分布（如果可用）
    subplot(2, 4, 1);
    if isfield(stats, 'all_errors') && ~isempty(stats.all_errors) && ~any(isnan(stats.all_errors))
        bar(stats.all_errors, 'FaceColor', [0.3, 0.5, 0.8]);
        hold on;
        plot([1, length(stats.all_errors)], [stats.mean_error, stats.mean_error], 'r--', 'LineWidth', 2);
        xlabel('匹配点编号');
        ylabel('误差 (像素)');
        title('各点重投影误差');
        legend('点误差', '平均误差', 'Location', 'best');
        grid on;
    else
        text(0.5, 0.5, '误差数据不可用', 'HorizontalAlignment', 'center');
        axis off;
    end
    
    % 子图2: 误差直方图（如果可用）
    subplot(2, 4, 2);
    if isfield(stats, 'all_errors') && ~isempty(stats.all_errors) && ~any(isnan(stats.all_errors))
        histogram(stats.all_errors, 15, 'FaceColor', [0.8, 0.4, 0.2], 'EdgeColor', 'black');
        hold on;
        xline(stats.mean_error, 'r--', 'LineWidth', 2, 'Label', sprintf('平均: %.2f', stats.mean_error));
        if isfield(stats, 'median_error')
            xline(stats.median_error, 'g--', 'LineWidth', 2, 'Label', sprintf('中位数: %.2f', stats.median_error));
        end
        xlabel('重投影误差 (像素)');
        ylabel('匹配点数量');
        title('误差分布直方图');
        grid on;
    else
        text(0.5, 0.5, '误差数据不可用', 'HorizontalAlignment', 'center');
        axis off;
    end
    
    % 子图3: 匹配点可视化（如果可用）
    subplot(2, 4, 3);
    if isfield(stats, 'inlier_points_distorted') && isfield(stats, 'inlier_points_reference')
        try
            showMatchedFeatures(rgb2gray(imread('数据/正常图片.png')), ...
                               rgb2gray(imread('数据/扭曲图片.png')), ...
                               stats.inlier_points_reference, stats.inlier_points_distorted, 'montage');
            title('特征点匹配结果');
        catch
            text(0.5, 0.5, '匹配点显示失败', 'HorizontalAlignment', 'center');
            axis off;
        end
    elseif isfield(stats, 'matched_points_distorted') && isfield(stats, 'matched_points_reference')
        try
            showMatchedFeatures(rgb2gray(imread('数据/正常图片.png')), ...
                               rgb2gray(imread('数据/扭曲图片.png')), ...
                               stats.matched_points_reference, stats.matched_points_distorted, 'montage');
            title('特征点匹配结果');
        catch
            text(0.5, 0.5, '匹配点显示失败', 'HorizontalAlignment', 'center');
            axis off;
        end
    else
        text(0.5, 0.5, '匹配点数据不可用', 'HorizontalAlignment', 'center');
        axis off;
    end
    
    % 子图4: 质量总结
    subplot(2, 4, 4);
    axis off;
    text(0.1, 0.9, '质量评估总结', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'blue');
    text(0.1, 0.7, sprintf('评级: %s', quality_grade), 'FontSize', 14, 'FontWeight', 'bold');
    text(0.1, 0.6, sprintf('平均误差: %.3f 像素', stats.mean_error), 'FontSize', 12);
    
    if isfield(stats, 'inlier_ratio')
        text(0.1, 0.5, sprintf('匹配成功率: %.1f%%', stats.inlier_ratio * 100), 'FontSize', 12);
    end
    
    if isfield(stats, 'num_inliers')
        text(0.1, 0.4, sprintf('内点数量: %d 个', stats.num_inliers), 'FontSize', 12);
    end
    
    % 子图5: 误差空间分布（如果可用）
    subplot(2, 4, 5);
    if isfield(stats, 'inlier_points_reference') && isfield(stats, 'all_errors') && ~any(isnan(stats.all_errors))
        try
            reference_locations = stats.inlier_points_reference.Location;
            scatter(reference_locations(:,1), reference_locations(:,2), 40, stats.all_errors, 'filled');
            colorbar;
            axis equal;
            xlabel('图像X坐标');
            ylabel('图像Y坐标');
            title('匹配点误差空间分布');
            text(0.05, 0.95, '颜色越红表示误差越大', 'Units', 'normalized', ...
                'BackgroundColor', 'white', 'FontSize', 9);
        catch
            text(0.5, 0.5, '空间分布数据不可用', 'HorizontalAlignment', 'center');
            axis off;
        end
    else
        text(0.5, 0.5, '空间分布数据不可用', 'HorizontalAlignment', 'center');
        axis off;
    end
    
    % 子图6: 替代箱线图
    subplot(2, 4, 6);
    if isfield(stats, 'all_errors') && ~isempty(stats.all_errors) && ~any(isnan(stats.all_errors))
        % 使用排序曲线替代箱线图
        errors_sorted = sort(stats.all_errors);
        plot(errors_sorted, 'r-', 'LineWidth', 2);
        hold on;
        plot([1, length(errors_sorted)], [stats.mean_error, stats.mean_error], 'b--', 'LineWidth', 2);
        xlabel('排序后的点');
        ylabel('误差 (像素)');
        title('误差排序分布');
        legend('排序误差', '平均值', 'Location', 'best');
        grid on;
    else
        text(0.5, 0.5, '误差数据不可用', 'HorizontalAlignment', 'center');
        axis off;
    end
    
    % 子图7: 统计表格
    subplot(2, 4, 7);
    axis off;
    stats_text = {
        '详细统计',...
        '========',...
        sprintf('平均值: %.3f', stats.mean_error)
    };
    
    if isfield(stats, 'max_error')
        stats_text{end+1} = sprintf('最大值: %.3f', stats.max_error);
    end
    
    if isfield(stats, 'std_error')
        stats_text{end+1} = sprintf('标准差: %.3f', stats.std_error);
    end
    
    if isfield(stats, 'median_error')
        stats_text{end+1} = sprintf('中位数: %.3f', stats.median_error);
    end
    
    if isfield(stats, 'rmse_error')
        stats_text{end+1} = sprintf('RMSE: %.3f', stats.rmse_error);
    end
    
    text(0.1, 0.8, stats_text, 'FontSize', 11, 'VerticalAlignment', 'top');
    
    % 子图8: 改进建议
    subplot(2, 4, 8);
    axis off;
    if stats.mean_error > 8.0
        advice = {
            '改进建议:',...
            '• 检查图像质量',...
            '• 调整匹配参数',...
            '• 尝试其他特征算法',...
            '• 增加图像预处理'
        };
        color = 'red';
    elseif stats.mean_error > 5.0
        advice = {
            '改进建议:',...
            '• 优化匹配阈值',...
            '• 验证特征点质量',...
            '• 调整RANSAC参数'
        };
        color = 'orange';
    elseif stats.mean_error > 2.0
        advice = {
            '当前状态:',...
            '• 精度可接受',...
            '• 可进一步优化',...
            '• 检查个别异常点'
        };
        color = 'blue';
    else
        advice = {
            '当前状态:',...
            '• 精度优秀',...
            '• 保持当前参数',...
            '• 结果可靠'
        };
        color = 'green';
    end
    text(0.1, 0.8, advice, 'FontSize', 11, 'VerticalAlignment', 'top', 'Color', color);
    
    fprintf('\n评估完成！\n');
end