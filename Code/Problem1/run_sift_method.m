function run_sift_method(data_folder)
    % 运行SIFT方法
    
    fprintf('\n - SIFT特征匹配 ===\n');
    
    try
        [result, tform, stats] = sift_correction(data_folder);
        evaluation_auto(stats, 'SIFT特征匹配');
    catch ME
        fprintf('SIFT方法执行失败: %s\n', ME.message);
    end
end