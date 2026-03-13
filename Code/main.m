%% 主程序：遥感影像几何校正系统
clear; clc; close all;

%% 数据路径设置
data_folder = '数据';

%% 添加函数路径到 MATLAB 搜索路径
fprintf('添加函数路径...\n');
addpath('Problem1');
addpath('Problem2');
addpath(fullfile('Problem2', 'RIFT2'));   % 添加RIFT2 方法
addpath('综合评估');

%% 主菜单循环
while true
    fprintf('\n========================================\n');
    fprintf('=== 遥感影像几何校正系统 ===\n');
    fprintf('请选择要解决的问题：\n');
    fprintf('1 - 问题一：普通图像几何校正（扭曲图片 / 正常图片）\n');
    fprintf('2 - 问题二：武汉遥感影像几何校正\n');
    fprintf('3 - 综合对比评估（问题一 + 问题二）\n');
    fprintf('0 - 退出程序\n');
    fprintf('========================================\n');
    
    main_choice = input('请输入选择 (0-3): ');
    
    switch main_choice
        case 0
            fprintf('已退出程序。\n');
            break;
            
        %% ================== 问题一：普通图像几何校正 ==================
        case 1
            while true
                fprintf('\n--- 问题一：普通图像几何校正 ---\n');
                fprintf('可选方法：\n');
                fprintf('1 - SIFT 自动特征匹配\n');
                fprintf('2 - SURF 特征匹配\n');
                fprintf('3 - 交互式图像纠正\n');
                fprintf('0 - 返回上一级菜单\n');
                
                sub1_choice = input('请输入选择 (0-3): ');
                
                switch sub1_choice
                    case 0
                        fprintf('返回主菜单。\n');
                        break;
                        
                    case 1
                        %  SIFT 方法
                        fprintf('\n运行：问题一 -SIFT 自动特征匹配...\n');
                        try
                            run_sift_method(data_folder);
                        catch ME
                            fprintf('运行 SIFT 方法时出错：%s\n', ME.message);
                        end
                        
                    case 2
                        % SURF 方法
                        fprintf('\n运行：问题一 -SURF 特征匹配...\n');
                        try
                            run_surf_method(data_folder);
                        catch ME
                            fprintf('运行 SURF 方法时出错：%s\n', ME.message);
                        end
                        
                    case 3
                        % 交互式方法
                        fprintf('\n运行：问题一 - 交互式图像纠正...\n');
                        try
                            run_interactive_methods(data_folder);
                        catch ME
                            fprintf('运行交互式纠正方法时出错：%s\n', ME.message);
                        end
                        
                    otherwise
                        fprintf('无效选择，请重新输入。\n');
                end
                
                if sub1_choice == 0
                    % 跳出问题一子菜单，回到主菜单
                    break;
                end
            end
            
        %% ================== 问题二：武汉遥感影像几何校正 ==================
        case 2
            while true
                fprintf('\n--- 问题二：武汉遥感影像几何校正 ---\n');
                fprintf('可选方法：\n');
                fprintf('1 - 手动控制点投影变换、自动选择最优模型\n');
                fprintf('2 - 仿射变换、二次多项式变换\n');
                fprintf('3 - RIFT2 特征匹配 \n');
                fprintf('0 - 返回上一级菜单\n');
                
                sub2_choice = input('请输入选择 (0-3): ');
                
                switch sub2_choice
                    case 0
                        fprintf('返回主菜单。\n');
                        break;
                        
                    case 1
                        % （手动控制点 + 自动 SIFT）
                        fprintf('\n运行：问题二 -手动控制点投影变换（自动选择最优模型）...\n');
                        try
                            run_methods1(data_folder);
                        catch ME
                            fprintf('运行方法集时出错：%s\n', ME.message);
                        end
                        
                    case 2
                        % 仿射 + 二次多项式
                        fprintf('\n运行：问题二 - 仿射 + 二次多项式变换...\n');
                        try
                            run_methods2(data_folder);
                        catch ME
                            fprintf('运行方法集时出错：%s\n', ME.message);
                        end
                        
                    case 3
                        % RIFT2 方法
                        fprintf('\n运行：问题二 -RIFT2 特征匹配...\n');
                        try
                    
                            % 
                            my_demo;
                        catch ME
                            fprintf('运行RIFT2 方法时出错：%s\n', ME.message);
                        end
                        
                    otherwise
                        fprintf('无效选择，请重新输入。\n');
                end
                
                if sub2_choice == 0
                    % 跳出问题二子菜单，回到主菜单
                    break;
                end
            end
            
        %% ================== 综合对比评估 ==================
        case 3
            fprintf('\n运行：综合对比评估（问题一 + 问题二）...\n');
            try
                run_comprehensive_evaluation(data_folder);
            catch ME
                fprintf('运行综合对比评估时出错：%s\n', ME.message);
            end
            
        otherwise
            fprintf('无效选择，请输入 0~3 之间的数字。\n');
    end
end
