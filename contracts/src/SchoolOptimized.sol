// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SchoolOptimized - 分数排序学生管理
 * @notice 根据学生分数维护有序链表的合约
 * @dev 实现功能：
 *      1. 将新学生添加到按分数排序的列表中（分数相同则按添加顺序）
 *      2. 提高学生分数（保持列表有序）
 *      3. 降低学生分数（保持列表有序）
 *      4. 从名单中删除学生
 *      5. 获取前K名学生名单
 *
 * 技术实现：
 * - 使用单向链表存储学生，按分数降序排列
 * - 分数高的学生排在链表前面
 * - 通过 candidateStudent 参数指定插入位置，避免遍历
 *
 * 排序规则：
 * - 分数高的在前（降序）
 * - 分数相同时，保持原有顺序（稳定排序）
 *
 * 示例：
 * - 链表：GUARD -> Alice(90) -> Bob(80) -> Charlie(70)
 * - 添加 David(85) 时，提供 candidateStudent = Bob
 * - 结果：GUARD -> Alice(90) -> David(85) -> Bob(80) -> Charlie(70)
 */
contract SchoolOptimized {

    // 存储学生分数
    // key: 学生地址，value: 分数
    mapping(address => uint256) public scores;

    // 存储每个学生的下一个学生地址（链表）
    // key: 当前学生地址，value: 下一个学生地址
    mapping(address => address) private _nextStudents;

    // 链表当前大小
    uint256 public listSize;

    // 哨兵节点，作为链表头部
    // 使用 address(1) 作为特殊标记
    address constant private GUARD = address(1);

    /**
     * @dev 构造函数，初始化哨兵节点
     */
    constructor() {
        _nextStudents[GUARD] = GUARD;
    }

    /**
     * @notice 添加学生到有序列表
     * @param student 学生地址
     * @param score 初始分数
     * @param candidateStudent 参考学生地址（用于确定插入位置）
     *
     * @dev 添加到 candidateStudent 之后的位置
     *
     * 验证逻辑：
     * 1. 学生地址不能已存在
     * 2. candidateStudent 必须是有效学生（或 GUARD）
     * 3. 新学生分数必须在 candidateStudent 和其后继之间
     *
     * 示例：
     * - 现有：GUARD -> A(90) -> B(80) -> C(70)
     * - 添加 D(85)，candidateStudent = A
     * - 结果：GUARD -> A(90) -> D(85) -> B(80) -> C(70)
     *
     * 注意：分数相同时，新学生会放在 candidateStudent 之后
     */
    function addStudent(address student, uint256 score, address candidateStudent) public {
        // 检查学生是否已存在
        require(_nextStudents[student] == address(0), "Student already exists");
        // 检查候选学生是否有效
        require(_nextStudents[candidateStudent] != address(0), "Invalid candidate student");
        // 验证分数排序正确
        require(_verifyIndex(candidateStudent, score, _nextStudents[candidateStudent]), "Invalid score position");

        // 更新分数
        scores[student] = score;
        // 插入链表
        _nextStudents[student] = _nextStudents[candidateStudent];
        _nextStudents[candidateStudent] = student;
        listSize++;
    }

    /**
     * @notice 提高学生分数
     * @param student 学生地址
     * @param score 要增加的分数
     * @param oldCandidateStudent 调整前的前驱学生
     * @param newCandidateStudent 调整后的前驱学生
     *
     * @dev 封装 updateScore，将新旧分数差值作为参数
     *
     * 注意：
     * - 分数增加后可能导致排名上升
     * - 需要提供新的插入位置
     */
    function increaseScore(
        address student,
        uint256 score,
        address oldCandidateStudent,
        address newCandidateStudent
    ) public {
        // 计算新分数并更新
        updateScore(student, scores[student] + score, oldCandidateStudent, newCandidateStudent);
    }

    /**
     * @notice 降低学生分数
     * @param student 学生地址
     * @param score 要减少的分数
     * @param oldCandidateStudent 调整前的前驱学生
     * @param newCandidateStudent 调整后的前驱学生
     *
     * @dev 封装 updateScore，减去分数
     *
     * 注意：
     * - 分数减少后可能导致排名下降
     * - 需要提供新的插入位置
     */
    function reduceScore(
        address student,
        uint256 score,
        address oldCandidateStudent,
        address newCandidateStudent
    ) public {
        updateScore(student, scores[student] - score, oldCandidateStudent, newCandidateStudent);
    }

    /**
     * @notice 更新学生分数并调整位置
     * @param student 学生地址
     * @param newScore 新的分数
     * @param oldCandidateStudent 当前位置的前驱学生
     * @param newCandidateStudent 新位置的前驱学生
     *
     * @dev 两种更新策略：
     * 1. 同一位置更新：只改变分数，不移动节点
     * 2. 换位更新：先删除再重新插入
     *
     * 优化点：
     * - 如果新分数位置与原位置相同，只需更新分数
     * - 如果位置改变，需要重新插入节点
     *
     * 安全检查：
     * - 学生必须存在
     * - 两个候选学生必须有效
     * - 新分数位置必须满足排序规则
     */
    function updateScore(
        address student,
        uint256 newScore,
        address oldCandidateStudent,
        address newCandidateStudent
    ) public {
        // 验证学生和候选学生存在
        require(_nextStudents[student] != address(0), "Student does not exist");
        require(_nextStudents[oldCandidateStudent] != address(0), "Invalid old candidate");
        require(_nextStudents[newCandidateStudent] != address(0), "Invalid new candidate");

        // 同一位置更新：只需要验证分数调整后仍在正确范围
        if (oldCandidateStudent == newCandidateStudent) {
            require(_isPrevStudent(student, oldCandidateStudent), "Invalid old candidate position");
            require(_verifyIndex(newCandidateStudent, newScore, _nextStudents[student]), "Invalid new score position");
            scores[student] = newScore;
        } else {
            // 位置改变：先删除再添加
            removeStudent(student, oldCandidateStudent);
            addStudent(student, newScore, newCandidateStudent);
        }
    }

    /**
     * @notice 从列表中移除学生
     * @param student 学生地址
     * @param candidateStudent 已知的前驱学生
     *
     * @dev 优化版本，提供前驱节点避免遍历
     *
     * 操作：
     * 1. 将前驱节点的 next 指向学生的下一个
     * 2. 清除学生的 next 指针
     * 3. 重置学生分数为 0
     * 4. 链表大小减 1
     */
    function removeStudent(address student, address candidateStudent) public {
        require(_nextStudents[student] != address(0), "Student does not exist");
        require(_isPrevStudent(student, candidateStudent), "Invalid candidate student");

        // 从链表中移除
        _nextStudents[candidateStudent] = _nextStudents[student];
        _nextStudents[student] = address(0);
        // 重置分数
        scores[student] = 0;
        listSize--;
    }

    /**
     * @notice 获取前 K 名学生
     * @param k 要获取的学生数量
     * @return address[] 学生地址数组
     *
     * @dev 从链表头部开始遍历，返回前 k 个学生
     *
     * 注意：
     * - k 不能超过链表大小
     * - 返回的是按分数降序排列的学生列表
     */
    function getTop(uint256 k) public view returns (address[] memory) {
        require(k <= listSize, "k exceeds list size");

        address[] memory studentLists = new address[](k);
        address currentAddress = _nextStudents[GUARD];

        for (uint256 i = 0; i < k; ++i) {
            studentLists[i] = currentAddress;
            currentAddress = _nextStudents[currentAddress];
        }

        return studentLists;
    }

    /**
     * @notice 验证分数插入位置是否正确
     * @param prevStudent 前驱学生地址
     * @param newValue 新分数
     * @param nextStudent 后继学生地址
     * @return bool 位置是否有效
     *
     * @dev 排序规则验证：
     * - 如果前驱是 GUARD（链表头部），新分数无下限
     * - 否则新分数必须 <= 前驱分数
     * - 如果后继是 GUARD（链表尾部），新分数无上限
     * - 否则新分数必须 > 后继分数
     *
     * 注意：使用 >= 而不是 >，允许相同分数相邻
     */
    function _verifyIndex(address prevStudent, uint256 newValue, address nextStudent) internal view returns (bool) {
        return (prevStudent == GUARD || scores[prevStudent] >= newValue) &&
            (nextStudent == GUARD || newValue > scores[nextStudent]);
    }

    /**
     * @notice 检查是否为前驱关系
     * @param student 学生地址
     * @param prevStudent 候选前驱学生
     * @return bool 是否为前驱
     *
     * @dev 通过检查 prevStudent 的 next 是否指向 student 来验证
     */
    function _isPrevStudent(address student, address prevStudent) internal view returns (bool) {
        return _nextStudents[prevStudent] == student;
    }
}
