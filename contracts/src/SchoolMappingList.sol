pragma solidity ^0.8.0;

/*
创建一个“学校"智能合约来收集学生地址。合约必须具有3个主要功能：
1.在合约中添加或删除学生。
2.询问给定的学生地址是否属于学校。
3.获取所有学生的名单。
*/

// 普通实现
contract SchoolMapping {

    mapping(address => bool) private students;

    constructor()  {}

    function addStudent(address student) public {
        require(!isStudent(student));
        students[student] = true;
    }

    function removeStudent(address student) public {
        require(isStudent(student));
        students[student] = false;
    }

    function isStudent(address student) public view returns (bool) {
        return students[student];
    }

    function getStudents() public pure returns (address[] memory) {
        revert("cannot traverse mapping");
    }
}

// 数组实现
contract SchoolBaseArray {

    address[] private  students;

    constructor()  {}

    function addStudent(address student) public {
        require(!isStudent(student));
        students.push(student);
    }

    function removeStudent(address student) public {
        (bool found, uint256 index) = _getStudentIndex(student);
        require(found);

        for (uint256 i = index; i < students.length; ++i) {
            students[i - 1] = students[i];
        }
        students.pop();
    }

    function isStudent(address student) public view returns (bool) {
        (bool found,) = _getStudentIndex(student);
        return found;
    }

    function getStudents() public view returns (address[] memory) {
        return students;
    }

    function _getStudentIndex(address student) internal view returns (bool, uint256) {
        for (uint256 i = 0; i < students.length; ++i) {
            if (student == students[i]) {
                return (true, i);
            }
        }
        return (false, 0);
    }
}

// 数组链表实现
contract SchoolMappingList {

    mapping(address => address) private _nextStudents;
    uint public listSize;

    address constant private GUARD = address(1);

    constructor()  {
        _nextStudents[GUARD] = GUARD;
    }

    function addStudent(address student) public {
        require(!isStudent(student));

        _nextStudents[student] = _nextStudents[GUARD];
        _nextStudents[GUARD] = student;
        listSize ++;
    }

    function removeStudent(address student) public {
        require(isStudent(student));
        address prevStudent = _getPrevStudent(student);

        _nextStudents[prevStudent] = _nextStudents[student];
        _nextStudents[student] = address(0);
        listSize --;
    }

    function removeStudent2(address student, address prevStudent) public {
        require(isStudent(student));
        require(_nextStudents[prevStudent] == student);

        _nextStudents[prevStudent] = _nextStudents[student];
        _nextStudents[student] = address(0);
        listSize --;
    }

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

    function isStudent(address student) public view returns (bool) {
        return _nextStudents[student] != address(0);
    }

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

