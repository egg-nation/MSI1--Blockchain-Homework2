// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <=0.8.15;

contract SampleToken {

    string public name = "Sample Token";
    string public symbol = "TOK";

    uint256 private _totalSupply;
    uint256 private _totalSales;

    address owner;
    address sampleTokenSaleAddress;

    event Transfer(address indexed _from,
                   address indexed _to,
                   uint256 _value);

    event Approval(address indexed _owner,
                   address indexed _spender,
                   uint256 _value);

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowance;

    constructor(uint256 _initialSupply) {

        _balances[msg.sender] = _initialSupply;
        _totalSupply = _initialSupply;

        _totalSales = 0;
        owner = msg.sender;
        sampleTokenSaleAddress = msg.sender;

        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    // warnings
    string private restrictedToOwner = "RESTRICTION: This function can only be called by the owner (1).";
    string private notEnoughBalanceMoney = "Your balance is less than the minimum sum of money needed (1).";
    string private moreThanApproved = "You are trying to transfer more money than you were approved to do (1).";

    modifier restrictToOwner() {

        require(owner == msg.sender, restrictedToOwner);
        _;
    }

    modifier hasEnoughBalanceMoney(address _from, uint256 _value) {

        require(_balances[_from] >= _value, notEnoughBalanceMoney);
        _;
    }

    function balanceOf(address _owner) public view returns (uint256) {

        return _balances[_owner];
    }

    function totalSupply() public view returns (uint256) {

        return _totalSupply;
    }

    function transfer(address _to, uint256 _value) public hasEnoughBalanceMoney(msg.sender, _value) returns (bool success) {

        _balances[msg.sender] -= _value;
        _balances[_to] += _value;

        mint(_value);
        emit Transfer(msg.sender, _to, _value);

        return true;
    }

    function mint(uint256 _value) private {

        _totalSales = _totalSales + _value;

        while (_totalSales > 10000) {

            _totalSupply++;

            _balances[owner]++;
            _allowance[owner][sampleTokenSaleAddress]++;

            _totalSales = _totalSales - 10000;

            emit Transfer(address(0), owner, 1);
        }
    }

    function approve(address _spender, uint256 _value) public hasEnoughBalanceMoney(msg.sender, _value) returns (bool success) {

        _allowance[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);

        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {

        return _allowance[_owner][_spender];
    }

    function transferFrom(address _from, address _to, uint256 _value) public hasEnoughBalanceMoney(_from, _value) returns (bool success) {

        require(_value <= _allowance[_from][msg.sender], moreThanApproved);

        _balances[_from] -= _value;
        _balances[_to] += _value;
        _allowance[_from][msg.sender] -= _value;

        emit Transfer(_from, _to, _value);

        return true;
    }

    function setTokenSaleAddress(address _tokenSaleAddress) external restrictToOwner {

        sampleTokenSaleAddress = _tokenSaleAddress;
    }
}

contract SampleTokenSale {

    SampleToken public tokenContract;
    uint256 public tokenPrice;
    address owner;

    uint256 public tokensSold;

    event Sell(address indexed _buyer, uint256 indexed _amount);

    constructor(SampleToken _tokenContract, uint256 _tokenPrice) {

        owner = msg.sender;
        tokenContract = _tokenContract;
        tokenPrice = _tokenPrice;
    }

    // warnings
    string private restrictedToOwner = "RESTRICTION: This function can only be called by the owner (2).";
    string private notEnoughMoney = "More money is needed to perform this action (2).";
    string private notEnoughTokens = "The seller doesn't have enough tokens in stock to perform this action (2).";
    string private notEnoughBalance = "The owner's balance is too little (2).";
    string private moreThanApproved = "You are trying to transfer more money than you were approved to do (2).";
    string private failedTransferringTokensToBuyer = "An error has occurred while transferring the tokens to the buyer (2).";
    string private failedTransferringToOwner = "An error has occurred while transferring the tokens to the owner (2).";
    string private failedTransferringFromOwnerToOwner = "An error has occurred while transferring the tokens to owner from owner (2).";

    modifier restrictToOwner() {

        require(owner == msg.sender, restrictedToOwner);
        _;
    }

    function buyTokens(uint256 _numberOfTokens) public payable {

        require(msg.value >= _numberOfTokens * tokenPrice, notEnoughMoney);
        require(tokenContract.allowance(owner, address(this)) >= _numberOfTokens, notEnoughTokens);
        require(tokenContract.balanceOf(owner) >= _numberOfTokens, notEnoughBalance);

        tokensSold += _numberOfTokens;
        uint256 remainingBalance = msg.value - _numberOfTokens * tokenPrice;

        require(tokenContract.transferFrom(owner, msg.sender, _numberOfTokens), failedTransferringTokensToBuyer);
        payable(msg.sender).transfer(remainingBalance);

        emit Sell(msg.sender, _numberOfTokens);
    }

    function updateTokenPrice(uint256 _tokenPrice) external restrictToOwner {

        tokenPrice = _tokenPrice;
    }

    function endSale() external restrictToOwner {

        require(tokenContract.transfer(owner, tokenContract.balanceOf(address(this))), failedTransferringToOwner);
        require(tokenContract.transferFrom(owner, owner, tokenContract.allowance(owner, address(this))), failedTransferringFromOwnerToOwner);
        payable(msg.sender).transfer(address(this).balance);
    }
}

// attempt to integrate with auction from laboratory 6
contract Auction {

    SampleToken public tokenContract;

    address payable internal auction_owner;
    uint256 public auction_start;
    uint256 public auction_end;
    uint256 public highestBid;
    address public highestBidder;

    enum auction_state {

        CANCELLED, STARTED
    }

    struct car {

        string Brand;
        string Rnumber;
    }

    car public Mycar;
    address[] bidders;

    mapping(address => uint256) public bids;
    mapping(address => uint256) public bidder_index;

    auction_state public STATE;

    // warnings
    string private restrictedToOwner = "RESTRICTION: This function can only be called by the owner (3).";
    string private auctionOngoing = "The auction is ongoing (3).";
    string private auctionOpen = "You cannot withdraw now. The auction is still open (3).";
    string private winner = "You have won. The money will not be returned to you (3).";

    modifier an_ongoing_auction() {

        require(block.timestamp <= auction_end && STATE == auction_state.STARTED, auctionOngoing);
        _;
    }

    modifier only_owner() {
        
        require(msg.sender == auction_owner, restrictedToOwner);
        _;
    }

    modifier isNotWinner() {
        
        require(msg.sender != highestBidder, winner);
        _;
    }

    modifier hasAuctionEnded() {
        
        require(block.timestamp > auction_end || STATE == auction_state.CANCELLED, auctionOpen);
        _;
    }

    function bid(uint256) public virtual returns (bool) {}

    function withdraw() public virtual returns (bool) {}

    function cancel_auction() external virtual returns (bool) {}

    event BidEvent(address indexed highestBidder, uint256 highestBid);
    event WithdrawalEvent(address withdrawer, uint256 amount);
    event CanceledEvent(string message, uint256 time);
}

contract MyAuction is Auction {

    constructor(SampleToken _tokenContract, uint256 _biddingTime, address payable _owner, string memory _brand, string memory _Rnumber) {

        tokenContract = _tokenContract;

        auction_owner = _owner;
        auction_start = block.timestamp;
        auction_end = auction_start + _biddingTime * 1 hours;
        STATE = auction_state.STARTED;
        Mycar.Brand = _brand;
        Mycar.Rnumber = _Rnumber;
    }

    // warnings
    string private biddenTokensNotAllowed = "The bidden tokens were not allowed (4).";
    string private tokensRequired = "Please send tokens (4).";
    string private bidAlreadyPlaced = "You have already placed a bid (4).";
    string private higherBidRequired = "This is less than the current highest bid. Place a higher bid! (4).";
    string private amountIsZeroOrLess = "Withdraw an amount bigger than 0 (4).";
    string private failedTransferringWithdrawnTokens = "An error has occurred while transferring the withdrawed tokens (4).";
    string private failedTransferringTokensFromBid = "An error has occurred while transferring the tokens from the bid (4).";
    string private failedTakingWinnersTokens = "An error has occurred while taking the winner's tokens (4).";
    string private notThatManyBidders = "Index out of range. There are not that many bidders (4).";
    string private contractCannotBeDestructedAuctionOpen = "You can't destruct the contract, the auction is still open (4).";
    string private withdrawalNotPossibleAuctionOpen = "You can't withdraw, the auction is still open (4).";

    function get_owner() public view returns (address) {

        return auction_owner;
    }

    fallback() external payable {

    }

    receive() external payable {

    }

    function bid(uint256 value) public override an_ongoing_auction returns (bool) {

        require(tokenContract.allowance(msg.sender, address(this)) >= value, biddenTokensNotAllowed);
        require(value > 0, tokensRequired);
        require(bids[msg.sender] == 0, bidAlreadyPlaced);
        require(value > highestBid, higherBidRequired);

        highestBidder = msg.sender;
        highestBid = value;
        bidders.push(msg.sender);
        bids[msg.sender] = highestBid;
        bidder_index[msg.sender] = bidders.length - 1;

        require(tokenContract.transferFrom(msg.sender, address(this), value), failedTransferringTokensFromBid);
        emit BidEvent(highestBidder, highestBid);

        return true;
    }

    function cancel_auction() external override only_owner an_ongoing_auction returns (bool) {

        STATE = auction_state.CANCELLED;
        emit CanceledEvent("Auction Cancelled", block.timestamp);

        return true;
    }

    function withdraw() public override hasAuctionEnded isNotWinner returns (bool) {

        require(block.timestamp > auction_end || STATE == auction_state.CANCELLED, withdrawalNotPossibleAuctionOpen);

        uint256 amount;
        amount = bids[msg.sender];
        require(amount > 0, amountIsZeroOrLess);

        bids[msg.sender] = 0;
        removeBidder(bidder_index[msg.sender]);

        require(tokenContract.transfer(msg.sender, amount), failedTransferringWithdrawnTokens);
        emit WithdrawalEvent(msg.sender, amount);

        return true;
    }

    function takeWinnersMoney() external only_owner hasAuctionEnded {

        uint256 amount = bids[highestBidder];
        bids[highestBidder] = 0;
        require(tokenContract.transfer(msg.sender, amount), failedTakingWinnersTokens);
    }

    function removeBidder(uint256 index) private {

        require(index < bidders.length, notThatManyBidders);

        bidder_index[bidders[index]] = bidders.length - 1;
        bidders[index] = bidders[bidders.length - 1];
        bidder_index[bidders[index]] = index;

        bidders.pop();
    }

    function destruct_auction() external only_owner hasAuctionEnded returns (bool) {

        require(block.timestamp > auction_end || STATE == auction_state.CANCELLED, contractCannotBeDestructedAuctionOpen);

        bids[highestBidder] = 0;
        uint256 amount;

        for (uint256 i = 0; i < bidders.length; i++) {

            if (bids[bidders[i]] != 0) {

                amount = bids[bidders[i]];
                bids[bidders[i]] = 0;
                require(tokenContract.transfer(bidders[i], amount));
            }
        }

        selfdestruct(auction_owner);

        return true;
    }
}
