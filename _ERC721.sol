pragma solidity ^0.4.21;

interface ERC721 /* is ERC165 */ {
    
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    function balanceOf(address _owner) public view returns (uint256);
    function ownerOf(uint256 _tokenId) public view returns (address);    
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory data) public;
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) public;
    function transferFrom(address _from, address _to, uint256 _tokenId) public;
    function approve(address _approved, uint256 _tokenId) public;
    function setApprovalForAll(address _operator, bool _approved) public;
    function getApproved(uint256 _tokenId) public view returns (address);
    function isApprovedForAll(address _owner, address _operator) public view returns (bool);
}


interface ERC721TokenReceiver {
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes memory _data) public returns(bytes4);
}

interface ERC165 {
    // 어떤 인터페이스를 상속받았는지 확인하는 함수.
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

contract ERC721Implementation is ERC721 {
    // tokenId를 계정에 매핑
    mapping (uint256 => address) tokenOwner;
    // 주소:토큰 개수 매핑
    mapping(address => uint256) ownedTokensCount;
    // 토큰id: 주소
    mapping(uint256 => address) tokenApprovals;
    // 누가 누구에게 권한 부여를 했는가?
    mapping(address => mapping(address => bool)) operatorApprovals;
    // interface를 상속했는가?
    mapping(bytes4 => bool) supportedInterface;

    constructor() public {
        supportedInterface[0x80ac58cd] = true;
    }

    // 토큰 발행 함수, tokenId로 넘어온 값을 _to address에 저장. address에 토큰 개수 늘림.
    // _to : 발행한 토큰을 누구에게 보낼 것인지,
    // _tokenId: 토큰 번호. (1, 2, 3, ...)
    function mint(address _to, uint _tokenId) public {
        tokenOwner[_tokenId] = _to;
        ownedTokensCount[_to] += 1;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return ownedTokensCount[_owner];
    }

    function ownerOf(uint256 _tokenId) public view returns (address) {
        return tokenOwner[_tokenId];
    }

    // tokenId를 들고있는 from 계정에서 to 계정으로 옮기겠다.
    function transferFrom(address _from, address _to, uint256 _tokenId) public {
        address owner = ownerOf(_tokenId); // ownerOf를 public으로 변경했기 때문에 가능함.
        // 이 함수를 호출한 msg.sender와 owner가 같은지 체크. 필수
        // getApproved(tokenId) == msg.sender : owner로 부터 token을 전송할 수 있는 계정으로 부여받았는지 확인.
        require(msg.sender == owner || getApproved(_tokenId) == msg.sender || isApprovedForAll(owner, msg.sender)); 
        require(_from != address(0)); // 비어있지 않은지 체크
        require(_to != address(0)); // 비어있지 않은지 체크

        ownedTokensCount[_from] -= 1;
        tokenOwner[_tokenId] = address(0); // token 소유권을 삭제

        ownedTokensCount[_to] += 1;
        tokenOwner[_tokenId] = _to; // token 소유권을 _to로 변경.
    }

    // safeTransferfrom 은 transferFrom에서,, _to가 컨트랙트 주소일 때 체크 로직을 추가한 함수
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) public {
        transferFrom(_from, _to, _tokenId);

        // 토큰을 소유할 수 있는 계정이 아니면 transfer가 실행 안됨.

        if (isContract(_to)) {
            // token을 받을 수 있는 계정인지 확인
            // _to address가 ERC721TokenReceiver를 상속받았는지 확인,, 후 onERC721Received 함수 호출.
            // magic value return 확인.
            bytes4 returnValue = ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, '');
            require(returnValue == 0x150b7a02);
        }
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory data) public {
        // 컨트랙 주소에 data가 필요할 경우 이 함수를 선택하여 사용,,
    }

    // 소유자의 토큰 1개를 다른 계정이 대신 전송할 수 있게끔 하는 기능, 특정 토큰에 대한 권한.
    function approve(address _approved, uint256 _tokenId) public {
        address owner = ownerOf(_tokenId); // 토큰 소유자 계정
        require(_approved != owner);
        require(msg.sender == owner);

        tokenApprovals[_tokenId] = _approved;
    }

    function getApproved(uint256 _tokenId) public view returns (address) {
        return tokenApprovals[_tokenId];
    }
    // 소유자의 토큰 전체를 다른 계정이 대신 전송할 수 있게끔 하는 기능. 소유자 토큰에 대한 권한.
    function setApprovalForAll(address _operator, bool _approved) public {
        require(_operator != msg.sender); // 나 자신한테는 불필요
        operatorApprovals[msg.sender][_operator] = _approved;
    }

    function isApprovedForAll(address _owner, address _operator) public view returns (bool) {
        return operatorApprovals[_owner][_operator];
    }

    function supportsInterface(bytes4 interfaceID) public view returns (bool) {
        return supportedInterface[interfaceID];
    }

    function isContract(address _addr) private view returns (bool) {
        uint256 size;

        assembly { size:= extcodesize(_addr) }
        // size > 0: contract account, size = 0 : account
        return size > 0;
    }
}

// 컨트랙트에 토큰을 보내는 경우,, 경매 contract. ERC721TokenReceiver 상속하여 구현.
contract Auction is ERC721TokenReceiver {
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes memory _data) public returns(bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    function checkSupportsInterface(address _to, bytes4 interfaceID) public view returns (bool) {
        return ERC721Implementation(_to).supportsInterface(interfaceID);
    }
}
