function run_interactive_method(data_folder)
    % 运行所有交互式方法
    
    fprintf('\n===交互式图像纠正 ===\n');
    
    try
        [result, tform, stats] = interactive_correction(data_folder);
        evaluation_auto(stats, '交互式图像纠正');
    catch ME
        fprintf('交互式方法执行失败: %s\n', ME.message);
    end
end