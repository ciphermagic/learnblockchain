// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title 学校合约 - 学生管理三种实现方式对比
 * @notice 演示如何收集和管理学生地址
 * @dev 包含三种实现方式：
 *      1. SchoolMapping - 纯 Mapping 实现（高效查询，无法遍历）
 *      2. SchoolBaseArray - 数组实现（可遍历，删除效率低）
 *      3. SchoolMappingList - 链表实现（可遍历，删除高效）
 *
 * 链表实现原理：
 * - 使用 mapping(address => address) 存储每个学生地址的下一个学生地址
 * - 相当于单向链表，GUARD 作为头节点（哨兵节点）
 * - 添加：O(1)，删除：O(n)，查询：O(n)
 */

// ============================================================
// 方式1：纯 Mapping 实现
// 优点：添加/查询 O(1)，Gas 最低
// 缺点：无法遍历获取所有学生
// ============================================================

/**
 * @title SchoolMapping - 纯 Mapping 学生管理
 * @dev 使用 mapping 存储学生状态，查询高效但无法遍历
 *
 * 存储结构：
 * - students[address] => bool (是否为学生)
 *
 * 适用场景：
 * - 学生数量已知，只需查询单个学生
 * - 需要 O(1) 查找性能的场合
 *
 * 限制：
 * - 无法获取所有学生列表（Solidity 限制）
 */
contract SchoolMapping {

    // 存储学生地址到是否有效的映射
    // key: 学生地址，value: 是否为有效学生
    mapping(address => bool) private students;

    /**
     * @dev 构造函数
     */
    constructor()  {}

    /**
     * @notice 添加学生到学校
     * @param student 学生地址
     * @dev 安全性：检查学生是否已存在，防止重复添加
     *
     * Gas 消耗：约 20000 gas（首次写入）
     */
    function addStudent(address student) public {
        require(!isStudent(student), "Student already exists");
        students[student] = true;
    }

    /**
     * @notice 从学校移除学生
     * @param student 学生地址
     * @dev 安全性：检查学生是否存在
     *
     * 注意：只是将状态标记为 false，不会释放存储槽
     * 最佳实践：如果需要真正释放存储，可使用 delete students[student]
     */
    function removeStudent(address student) public {
        require(isStudent(student), "Student does not exist");
        students[student] = false;
    }

    /**
     * @notice 检查地址是否为学生
     * @param student 要检查的地址
     * @return bool 是否为学生
     *
     * 复杂度：O(1)
     */
    function isStudent(address student) public view returns (bool) {
        return students[student];
    }

    /**
     * @notice 获取所有学生列表
     * @dev 由于 Mapping 无法遍历，此函数直接回退
     *
     * 解决方案：使用数组或链表实现（见下方 SchoolMappingList）
     */
    function getStudents() public pure returns (address[] memory) {
        revert("Cannot traverse mapping - use SchoolMappingList instead");
    }
}

// ============================================================
// 方式2：数组实现
// 优点：可遍历获取所有学生
// 缺点：删除元素需要移动数组，O(n) 复杂度
// ============================================================

/**
 * @title SchoolBaseArray - 数组学生管理
 * @dev 使用动态数组存储学生，可遍历但删除效率低
 *
 * 存储结构：
 * - students[] => address[] (学生地址数组)
 *
 * 复杂度分析：
 * - 添加：O(1)，数组末尾追加
 * - 删除：O(n)，需要移动数组元素
 * - 查询：O(n)，线性扫描
 *
 * 适用场景：
 * - 学生数量少
 * - 删除操作不频繁
 */
contract SchoolBaseArray {

    // 存储所有学生地址的动态数组
    address[] private students;

    /**
     * @dev 构造函数
     */
    constructor()  {}

    /**
     * @notice 添加学生到学校
     * @param student 学生地址
     * @dev 检查学生是否已存在（线性扫描）
     *
     * Gas 消耗：
     * - 首次添加：约 65000 gas（含数组扩展）
     * - 后续添加：约 45000 gas
     */
    function addStudent(address student) public {
        require(!isStudent(student), "Student already exists");
        students.push(student);
    }

    /**
     * @notice 从学校移除学生
     * @param student 学生地址
     * @dev 使用顺序移动策略：将待删除元素后面的所有元素向前移动一位
     *
     * 算法：
     * 1. 找到学生索引
     * 2. 将索引后所有元素向前移动一位
     * 3. pop 最后一个元素
     *
     * 注意：此实现保持原有顺序，但复杂度为 O(n)
     * 可选优化：使用 swap-and-pop（改变顺序但 O(1)）
     */
    function removeStudent(address student) public {
        (bool found, uint256 index) = _getStudentIndex(student);
        require(found, "Student does not exist");

        // 将被删除元素后面的所有元素向前移动一位
        for (uint256 i = index; i < students.length - 1; ++i) {
            students[i] = students[i + 1];
        }
        students.pop();
    }

    /**
     * @notice 检查地址是否为学生
     * @param student 要检查的地址
     * @return bool 是否为学生
     * @dev 线性扫描整个数组
     */
    function isStudent(address student) public view returns (bool) {
        (bool found,) = _getStudentIndex(student);
        return found;
    }

    /**
     * @notice 获取所有学生列表
     * @return address[] 学生地址数组
     * @dev 直接返回存储数组的副本
     */
    function getStudents() public view returns (address[] memory) {
        return students;
    }

    /**
     * @notice 查找学生索引
     * @param student 学生地址
     * @return found 是否找到
     * @return index 学生所在索引
     * @dev 内部函数，线性扫描
     */
    function _getStudentIndex(address student) internal view returns (bool, uint256) {
        for (uint256 i = 0; i < students.length; ++i) {
            if (student == students[i]) {
                return (true, i);
            }
        }
        return (false, 0);
    }
}

// ============================================================
// 方式3：链表实现（推荐）
// 优点：添加/删除 O(1)，可遍历，保持插入顺序
// ============================================================

/**
 * @title SchoolMappingList - 链表学生管理
 * @dev 使用单向链表存储学生，兼顾效率与可遍历性
 *
 * 链表结构：
 *   GUARD -> A -> B -> C -> GUARD (循环)
 *
 * 存储原理：
 * - _nextStudents[当前学生] = 下一个学生地址
 * - _nextStudents[GUARD] = 第一个学生
 *
 * 特点：
 * - 添加：O(1)，直接在 GUARD 后插入
 * - 删除：O(n)，需要遍历找到前驱节点
 * - 遍历：O(n)
 * - Gas 优化：比数组更节省存储（无需预分配空间）
 *
 * 注意：GUARD 是哨兵节点，用于简化边界处理
 */
contract SchoolMappingList {

    // 存储每个学生地址的下一个学生地址
    // key: 当前学生地址，value: 下一个学生地址
    // 如果 value = address(0)，表示该学生已被删除
    mapping(address => address) private _nextStudents;

    // 链表当前大小
    uint public listSize;

    // 哨兵节点，作为链表头部
    // 使用 address(1) 作为特殊标记，不会和普通地址冲突
    // 循环链表：GUARD -> 第一个学生 -> ... -> 最后一个学生 -> GUARD
    address constant private GUARD = address(1);

    /**
     * @dev 构造函数，初始化哨兵节点指向自身（空链表）
     */
    constructor()  {
        _nextStudents[GUARD] = GUARD;
    }

    /**
     * @notice 添加学生到学校
     * @param student 学生地址
     * @dev 在链表头部（GUARD 之后）插入新学生
     *
     * 算法：
     * 1. 新学生指向原来 GUARD 指向的学生
     * 2. GUARD 指向新学生
     *
     * 示例：
     * - 原始：GUARD -> A -> B
     * - 添加 C 后：GUARD -> C -> A -> B
     *
     * Gas 消耗：约 35000 gas（两次 mapping 写入）
     */
    function addStudent(address student) public {
        require(!isStudent(student), "Student already exists");

        // 将新学生插入到链表头部
        _nextStudents[student] = _nextStudents[GUARD];
        _nextStudents[GUARD] = student;
        listSize++;
    }

    /**
     * @notice 从学校移除学生
     * @param student 学生地址
     * @dev 需要遍历找到前驱节点，然后跳过当前学生
     *
     * 算法：
     * 1. 遍历链表找到目标学生的前驱节点
     * 2. 将前驱节点的 next 指向当前学生的下一个
     * 3. 将当前学生的 next 设为 address(0)（标记为已删除）
     *
     * 复杂度：O(n)
     */
    function removeStudent(address student) public {
        require(isStudent(student), "Student does not exist");
        address prevStudent = _getPrevStudent(student);

        // 将前驱节点的下一个指向当前学生的下一个
        _nextStudents[prevStudent] = _nextStudents[student];
        _nextStudents[student] = address(0);  // 标记为已删除
        listSize--;
    }

    /**
     * @notice 从学校移除学生（已知前驱节点，优化版）
     * @param student 学生地址
     * @param prevStudent 已知的前驱学生地址
     * @dev 优化版本，调用者提供前驱节点，避免遍历
     *
     * 适用场景：
     * - 在已知前后关系的情况下使用（如批量操作）
     * - 可将复杂度降为 O(1)
     *
     * 安全检查：
     * - 验证学生存在
     * - 验证提供的 prevStudent 确实是当前学生的前驱
     */
    function removeStudent2(address student, address prevStudent) public {
        require(isStudent(student), "Student does not exist");
        require(_nextStudents[prevStudent] == student, "Invalid previous student");

        _nextStudents[prevStudent] = _nextStudents[student];
        _nextStudents[student] = address(0);
        listSize--;
    }

    /**
     * @notice 获取前驱学生节点
     * @param student 学生地址
     * @return address 前驱学生地址
     * @dev 从 GUARD 开始遍历直到找到目标学生的前一个
     *
     * 复杂度：O(n)
     * 如果找不到，返回 address(0)
     */
    function _getPrevStudent(address student) internal view returns (address) {
        address currentAddress = GUARD;
        while (_nextStudents[currentAddress] != GUARD) {
            if (_nextStudents[currentAddress] == student) {
                return currentAddress;
            }
            currentAddress = _nextStudents[currentAddress];
        }
        return address(0);
    }

    /**
     * @notice 检查地址是否为学生
     * @param student 要检查的地址
     * @return bool 是否为学生
     * @dev 通过检查 mapping 中是否存在指向来判断
     *
     * 原理：
     * - 如果是有效学生，其 _nextStudents[student] 不会是 address(0)
     * - 因为删除操作会将 _nextStudents[student] 设为 address(0)
     *
     * 复杂度：O(1)
     */
    function isStudent(address student) public view returns (bool) {
        return _nextStudents[student] != address(0);
    }

    /**
     * @notice 获取所有学生列表
     * @return address[] 学生地址数组
     * @dev 从 GUARD 开始遍历链表，将所有学生地址存入数组
     *
     * 注意：
     * - 先创建固定大小的数组（listSize）
     * - 然后遍历链表填充数组
     * - 返回顺序与插入顺序一致
     */
    function getStudents() public view returns (address[] memory) {
        address[] memory students = new address[](listSize);
        address currentAddress = _nextStudents[GUARD];
        for (uint256 i = 0; currentAddress != GUARD; ++i) {
            students[i] = currentAddress;
            currentAddress = _nextStudents[currentAddress];
        }
        return students;
    }
}
