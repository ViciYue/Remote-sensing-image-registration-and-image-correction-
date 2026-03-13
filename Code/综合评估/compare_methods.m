function compare_methods(results)
    % 方法对比分析
    
    fprintf('\n=== 方法对比分析 ===\n');
    
    % 收集所有方法的误差数据
    method_names = {};
    mean_errors = [];
    max_errors = [];
    std_errors = [];
    num_points = [];
    
    methods = fieldnames(results);
    
    for i = 1:length(methods)
        method = methods{i};
        if isfield(results.(method), 'mean_error') && ~isnan(results.(method).mean_error)
            method_names{end+1} = method;
            mean_errors(end+1) = results.(method).mean_error;
            max_errors(end+1) = results.(method).max_error;
            std_errors(end+1) = results.(method).std_error;
            
            if isfield(results.(method), 'num_points')
                num_points(end+1) = results.(method).num_points;
            elseif isfield(results.(method), 'num_inliers')
                num_points(end+1) = results.(method).num_inliers;
            else
                num_points(end+1) = NaN;
            end
        end
    end
    
    if isempty(method_names)
        fprintf('没有可用的方法数据进行对比。\n');
        return;
    end
    
    % 显示对比结果
    fprintf('\n各方法误差对比:\n');
    fprintf('%-25s %-10s %-10s %-10s %-10s\n', '方法', '平均误差', '最大误差', '标准差', '点数');
    fprintf('%-25s %-10s %-10s %-10s %-10s\n', '----', '--------', '--------', '------', '----');
    
    for i = 1:length(method_names)
        if ~isnan(num_points(i))
            fprintf('%-25s %-10.3f %-10.3f %-10.3f %-10d\n', ...
                method_names{i}, mean_errors(i), max_errors(i), std_errors(i), num_points(i));
        else
            fprintf('%-25s %-10.3f %-10.3f %-10.3f %-10s\n', ...
                method_names{i}, mean_errors(i), max_errors(i), std_errors(i), 'N/A');
        end
    end
    
    % 可视化对比
    figure('Name', '方法对比分析', 'Position', [100, 100, 1500, 900]);
    
    % 子图1: 平均误差对比
    subplot(2, 3, 1);
    bar(mean_errors, 'FaceColor', [0.2, 0.6, 0.8]);
    set(gca, 'XTickLabel', method_names, 'XTickLabelRotation', 45);
    ylabel('平均误差 (像素)');
    title('各方法平均误差对比');
    grid on;
    
    % 在柱状图上显示数值
    for i = 1:length(mean_errors)
        text(i, mean_errors(i) + 0.1, sprintf('%.3f', mean_errors(i)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    end
    
    % 子图2: 最大误差对比
    subplot(2, 3, 2);
    bar(max_errors, 'FaceColor', [0.8, 0.4, 0.2]);
    set(gca, 'XTickLabel', method_names, 'XTickLabelRotation', 45);
    ylabel('最大误差 (像素)');
    title('各方法最大误差对比');
    grid on;
    
    % 子图3: 标准差对比
    subplot(2, 3, 3);
    bar(std_errors, 'FaceColor', [0.4, 0.8, 0.4]);
    set(gca, 'XTickLabel', method_names, 'XTickLabelRotation', 45);
    ylabel('误差标准差 (像素)');
    title('各方法误差稳定性对比');
    grid on;
    
    % 子图4: 综合评分（误差越小分数越高）
    subplot(2, 3, 4);
    scores = 10 ./ (1 + mean_errors);  % 简单的评分公式
    bar(scores, 'FaceColor', [0.9, 0.7, 0.1]);
    set(gca, 'XTickLabel', method_names, 'XTickLabelRotation', 45);
    ylabel('综合评分 (分)');
    title('各方法综合评分 (分数越高越好)');
    grid on;
    
    % 在柱状图上显示数值
    for i = 1:length(scores)
        text(i, scores(i) + 0.1, sprintf('%.2f', scores(i)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    end
    
    % 子图5: 方法分类对比
    subplot(2, 3, 5);
    manual_indices = contains(method_names, {'liu', 'zhao'});
    auto_indices = contains(method_names, {'wang', 'xu'});
    
    manual_mean = mean(mean_errors(manual_indices));
    auto_mean = mean(mean_errors(auto_indices));
    
    categories = {'手动方法', '自动方法'};
    means = [manual_mean, auto_mean];
    
    bar(means, 'FaceColor', [0.6, 0.4, 0.8]);
    set(gca, 'XTickLabel', categories);
    ylabel('平均误差 (像素)');
    title('手动vs自动方法对比');
    grid on;
    
    for i = 1:length(means)
        text(i, means(i) + 0.1, sprintf('%.3f', means(i)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    end
    
    % 子图6: 总结报告
    subplot(2, 3, 6);
    axis off;
    
    [best_score, best_idx] = min(mean_errors);
    best_method = method_names{best_idx};
    
    summary_text = {
        '综合对比总结',...
        '============',...
        sprintf('参与对比方法: %d 个', length(method_names)),...
        '',...
        '最佳方法:',...
        sprintf('  %s', best_method),...
        sprintf('  平均误差: %.3f 像素', best_score),...
        '',...
        '方法分类:',...
        sprintf('  手动方法平均: %.3f 像素', manual_mean),...
        sprintf('  自动方法平均: %.3f 像素', auto_mean),...
        '',...
        '推荐建议:',...
        sprintf('  %s', iif(manual_mean < auto_mean, '推荐使用手动方法', '推荐使用自动方法'))
    };
    
    text(0.05, 0.95, summary_text, 'VerticalAlignment', 'top', 'FontSize', 11, ...
        'BackgroundColor', [0.96, 0.96, 0.96]);
    
    fprintf('\n对比分析完成！\n');
    fprintf('最佳方法: %s (平均误差: %.3f 像素)\n', best_method, best_score);
end

function result = iif(condition, trueValue, falseValue)
    % 条件判断函数
    if condition
        result = trueValue;
    else
        result = falseValue;
    end
end