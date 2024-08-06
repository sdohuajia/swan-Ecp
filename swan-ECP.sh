#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "特别鸣谢 大赌哥"
        echo "================================================================"
        echo "节点社区 Telegram 群组: https://t.me/niuwuriji"
        echo "节点社区 Telegram 频道: https://t.me/niuwuriji"
        echo "节点社区 Discord 社群: https://discord.gg/GbMV5EcNWF"
        echo "退出脚本，请按键盘 ctrl + C 退出即可"
        echo "请选择要执行的操作:"
        echo "1) 安装节点"
        echo "2) 查看ZK任务列表"
        echo "3) 查询节点日志"
        echo "4) 重新启动节点"
        echo "5) 查看当前运行的任务列表"
        echo "6) 检查 resource-exporter 日志"
        echo "7) 验证ECP环境是否已成功安装"
        echo "0) 退出"
        read -p "输入选项 (0-7): " choice

        case $choice in
            1)
                install_node
                ;;
            2)
                view_zk_task_list
                ;;
            3)
                query_node_logs
                ;;
            4)
                restart_node
                ;;
            5)
                view_running_tasks
                ;;
            6)
                check_resource_exporter_logs
                ;;
            7)
                verify_ecp_installation
                ;;
            0)
                echo "退出脚本..."
                exit 0
                ;;
            *)
                echo "无效的选项"
                ;;
        esac

        read -p "按任意键返回主菜单..."
    done
}

# 检查 resource-exporter 日志的函数
function check_resource_exporter_logs() {
    echo "检查 resource-exporter 日志..."
    docker logs -f resource-exporter
}

# 验证ECP环境是否已成功安装的函数
function verify_ecp_installation() {
    read -p "请输入您的公共IP: " public_ip
    read -p "请输入端口号: " port
    echo "验证ECP环境是否已成功安装..."
    curl -s http://$public_ip:$port/api/v1/computing/cp
}

# 安装节点的函数
function install_node() {
    # 下载并运行 setup.sh 脚本
    echo "下载并运行 setup.sh 脚本..."
    curl -fsSL https://raw.githubusercontent.com/swanchain/go-computing-provider/releases/ubi/setup.sh | bash

    # 提供用户选择下载参数的选项
    echo "请选择要下载的参数文件:"
    echo "1) 512MiB 参数"
    echo "2) 32GiB 参数"
    read -p "输入选项 (1 或 2): " param_choice

case $param_choice in
        1)
            echo "下载并运行 fetch-param-512.sh 脚本..."
            curl -fsSL https://raw.githubusercontent.com/swanchain/go-computing-provider/releases/ubi/fetch-param-512.sh | bash
            ;;
        2)
            echo "下载并运行 fetch-param-32.sh 脚本..."
            curl -fsSL https://raw.githubusercontent.com/swanchain/go-computing-provider/releases/ubi/fetch-param-32.sh | bash
            ;;
        *)
            echo "无效的选项"
            ;;
    esac


    # 下载 computing-provider
    echo "下载 computing-provider..."
    wget https://github.com/swanchain/go-computing-provider/releases/download/v0.6.2/computing-provider

    # 赋予权限
    echo "赋予 computing-provider 权限..."
    chmod -R 755 computing-provider

    # 初始化ECP存储库
    read -p "请输入您的公共IP: " public_ip
    read -p "请输入您要使用的端口 (默认 9085): " port
    port=${port:-9085}
    read -p "请输入您的节点名称: " node_name

    echo "初始化ECP存储库..."
    ./computing-provider init --multi-address=/ip4/$public_ip/tcp/$port --node-name=$node_name

    # 生成新的钱包地址或通过私钥导入钱包
    echo "请选择钱包操作:"
    echo "1) 生成新的钱包地址并存入 SwanETH"
    echo "2) 通过私钥导入钱包"
    read -p "输入选项 (1 或 2): " wallet_choice

    case $wallet_choice in
        1)
            echo "生成新的钱包地址并存入 SwanETH，参考以下命令："
            ./computing-provider wallet new
            ;;
        2)
            echo "通过私钥导入刚刚跨链到 Swan 主网的钱包，参考以下命令："
            ./computing-provider wallet import
            echo "输入私钥并按回车键，即可导入密钥成功！"
            ;;
        *)
            echo "无效的选项"
            ;;
    esac

    # 初始化ECP账户
    read -p "请输入您的 EVM 钱包地址作为 ownerAddress: " owner_address
    read -p "请输入您的 EVM 钱包地址作为 workerAddress: " worker_address
    read -p "请输入您的收益地址作为 beneficiary_address: " beneficiary_address

    echo "初始化ECP账户..."
    ./computing-provider account create \
        --ownerAddress $owner_address \
        --workerAddress $worker_address \
        --beneficiaryAddress $beneficiary_address \
        --task-types 1,2,4

    # 添加SWANCECP抵押贷款品
    read -p "请输入您的 EVM 钱包地址: " collateral_address
    read -p "请输入托管的 SWANC 数量 (建议 100以上): " collateral_amount

    echo "添加SWANCECP抵押贷款品..."
    ./computing-provider collateral add --ecp --from $collateral_address $collateral_amount

    # 存款至SwanETHSequencer账户
    read -p "请输入您的 EVM 钱包地址: " sequencer_address
    read -p "请输入存入的 ETH 数量: " eth_amount

    echo "存款至SwanETHSequencer账户..."
    ./computing-provider sequencer add --from $sequencer_address $eth_amount

    # 启动服务
    echo "启动服务..."
    export FIL_PROOFS_PARAMETER_CACHE=$PARENT_PATH

    read -p "您的系统是否有GPU? (y/n): " has_gpu
    if [ "$has_gpu" == "y" ]; then
        read -p "请输入您的GPU型号和核心数（例如 GeForce RTX 4090:16384）: " gpu_info
        export RUST_GPU_TOOLS_CUSTOM_GPU="$gpu_info"
    else
        echo "未检测到GPU，将跳过GPU设置。"
    fi

    nohup ./computing-provider ubi daemon >> cp.log 2>&1 &

    echo "所有操作完成！"
}

# 查看ZK任务列表的函数
function view_zk_task_list() {
    echo "查看ZK任务列表..."
    ./computing-provider ubi list --show-failed
}

# 查询节点日志的函数
function query_node_logs() {
    echo "查询节点日志..."
    cd ~/.swan/computing || exit
    tail -f ubi-ecp.log
}

# 重新启动节点的函数
function restart_node() {
    echo "正在修改 config.toml 文件..."

    # 切换到配置文件目录
    cd ~/.swan/computing || exit

    echo "请手动修改 config.toml 文件："
    echo "[UBI]"
    echo "EnableSequencer = true             # 将证明提交给 Sequencer 服务（默认值：true）"
    echo "AutoChainProof = false             # 当Sequencer没有足够的资金或服务不可用时，自动向Swan链提交证明"
    echo "修改此两处后，退出文件进行下一步"

    # 等待用户手动修改配置文件
    read -p "修改完成后，请按任意键继续..."

    # 执行计算节点的命令
    echo "请输入您的钱包地址: "
    read -r wallet_address
    echo "请输入存入的金额: "
    read -r amount

    echo "执行 sequencer add 命令..."
    ./computing-provider sequencer add --from "$wallet_address" "$amount"

    # 设置环境变量并重新启动服务
    export FIL_PROOFS_PARAMETER_CACHE=$PARENT_PATH

    read -p "您的系统是否有GPU? (y/n): " has_gpu
    if [ "$has_gpu" == "y" ]; then
        read -p "请输入您的GPU型号和核心数（例如 GeForce RTX 4090:16384）: " gpu_info
        export RUST_GPU_TOOLS_CUSTOM_GPU="$gpu_info"
    else
        echo "未检测到GPU，将跳过GPU设置。"
    fi

    echo "重新启动节点..."
    nohup ./computing-provider ubi daemon >> cp.log 2>&1 &

    echo "节点已重新启动。"
}

# 查看当前运行的任务列表的函数
function view_running_tasks() {
    echo "查看当前运行的任务列表..."
    ./computing-provider task list -v
}

# 运行主菜单函数
main_menu
