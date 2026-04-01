BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DP_DIR="${BASE_DIR}/DP"

# ================= 参数 =================
if [ -z "$1" ]; then
    echo "❌ 用法: bash debug.sh 材料名 [strain1 strain2 ...]"
    exit 1
fi

MAT="$1"
shift

MAT_DIR="${DP_DIR}/${MAT}"

if [ ! -d "${MAT_DIR}" ]; then
    echo "❌ 材料不存在: ${MAT_DIR}"
    exit 1
fi

# 默认 strain
if [ $# -eq 0 ]; then
    STRAINS=("undef" "0.01P" "0.01N" "0.02P" "0.02N")
else
    STRAINS=("$@")
fi

echo "🔧 Debug 修改: ${MAT}"

count=0

for strain in "${STRAINS[@]}"; do
    scf_dir="${MAT_DIR}/${strain}/scf"

    if [ ! -d "$scf_dir" ]; then
        echo "⚠️ 不存在: ${scf_dir}"
        continue
    fi

    echo "📂 处理: ${strain}"

    # ===== 备份 =====
    [ -f "${scf_dir}/INCAR" ] && cp "${scf_dir}/INCAR" "${scf_dir}/INCAR.bak"
    [ -f "${scf_dir}/vasp.sh" ] && cp "${scf_dir}/vasp.sh" "${scf_dir}/vasp.sh.bak"

    # ===== 清理旧输出（强烈建议）=====
    rm -f "${band_dir}/OUTCAR" "${band_dir}/OSZICAR" "${band_dir}/vasprun.xml"

    # ===== 写入 INCAR =====
    cat > "${scf_dir}/INCAR" << EOF
# ===== Global Parameters =====
ISTART = 0
ISPIN  = 1
LREAL  = .FALSE.
ENCUT  = 520
LWAVE  = .FALSE.
LCHARG = .TRUE.
ADDGRID= .TRUE.
LASPH  = .TRUE.
PREC   = Accurate

# ===== Static Calculation =====
ISMEAR = 0
SIGMA  = 0.05
LORBIT = 11
NELM   = 120
EDIFF  = 1E-08

ICORELEVEL = 1
EOF

    # ===== 写入 vasp.sh =====
    cat > "${scf_dir}/vasp.sh" << EOF
#!/bin/bash
#SBATCH -J vasp
#SBATCH -p debug
#SBATCH -n 1
#SBATCH --error=%J.err
#SBATCH --output=%J.out

module load intel/2021
module load gcc/9.5.0
module load vasp/6.3.0

mpirun -np 56 vasp_std

scontrol show job \$SLURM_JOBID
EOF

    # ===== 提交 =====
    echo "🚀 提交: ${strain}"
    (cd "${scf_dir}" && sbatch vasp.sh)

    count=$((count + 1))
    sleep 0.2
done

echo ""
echo "🎉 完成：${count} 个任务已提交"
