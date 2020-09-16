// SPDX-License-Identifier: MIT

pragma solidity ^0.5.17;

import "@openzeppelinV2/contracts/token/ERC20/IERC20.sol";
import "@openzeppelinV2/contracts/math/SafeMath.sol";
import "@openzeppelinV2/contracts/utils/Address.sol";
import "@openzeppelinV2/contracts/token/ERC20/SafeERC20.sol";

import "../../interfaces/curve/Curve.sol";

import "../../interfaces/vearn/EController.sol";
import "../../interfaces/vearn/Mintr.sol";
import "../../interfaces/vearn/Token.sol";

contract StrategyDAICurve {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    
    address constant public want = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address constant public v = address(0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01);
    address constant public vcrv = address(0xdF5e0e81Dff6FAF3A7e52BA697820c5e32D806A8);
    address constant public vvcrv = address(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c);
    address constant public curve = address(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);
    
    address constant public dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address constant public vdai = address(0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01);

    address constant public usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address constant public vusdc = address(0xd6aD7a6750A7593E092a9B218d66C0A814a3436e);

    address constant public usdt = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address constant public vusdt = address(0x83f798e925BcD4017Eb265844FDDAbb448f1707D);

    address constant public tusd = address(0x0000000000085d4780B73119b644AE5ecd22b376);
    address constant public vtusd = address(0x73a052500105205d34Daf004eAb301916DA8190f);

    
    address public governance;
    address public controller;
    
    constructor(address _controller) public {
        governance = msg.sender;
        controller = _controller;
    }
    
    function getName() external pure returns (string memory) {
        return "StrategyDAICurve";
    }
    
    function deposit() public {
        uint _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IERC20(want).safeApprove(v, 0);
            IERC20(want).safeApprove(v, _want);
            yERC20(v).deposit(_want);
        }
        uint _v = IERC20(v).balanceOf(address(this));
        if (_v > 0) {
            IERC20(v).safeApprove(curve, 0);
            IERC20(v).safeApprove(curve, _v);
            ICurveFi(curve).add_liquidity([_v,0,0,0],0);
        }
        uint _vcrv = IERC20(vcrv).balanceOf(address(this));
        if (_vcrv > 0) {
            IERC20(vcrv).safeApprove(vvcrv, 0);
            IERC20(vcrv).safeApprove(vvcrv, _vcrv);
            yERC20(vvcrv).deposit(_vcrv);
        }
    }
    
    // Controller only function for creating additional rewards from dust
    function withdraw(IERC20 _asset) external returns (uint balance) {
        require(msg.sender == controller, "!controller");
        require(want != address(_asset), "want");
        require(v != address(_asset), "v");
        require(vcrv != address(_asset), "vcrv");
        require(vvcrv != address(_asset), "vvcrv");
        balance = _asset.balanceOf(address(this));
        _asset.safeTransfer(controller, balance);
    }
    
    // Withdraw partial funds, normally used with a vault withdrawal
    function withdraw(uint _amount) external {
        require(msg.sender == controller, "!controller");
        uint _balance = IERC20(want).balanceOf(address(this));
        if (_balance < _amount) {
            _amount = _withdrawSome(_amount.sub(_balance));
            _amount = _amount.add(_balance);
        }
        
        address _vault = EController(controller).vaults(address(want));
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
        IERC20(want).safeTransfer(_vault, _amount);
        
    }
    
    // Withdraw all funds, normally used when migrating strategies
    function withdrawAll() external returns (uint balance) {
        require(msg.sender == controller, "!controller");
        _withdrawAll();
        
        
        balance = IERC20(want).balanceOf(address(this));
        
        address _vault = EController(controller).vaults(address(want));
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
        IERC20(want).safeTransfer(_vault, balance);
    }
    
    function withdrawUnderlying(uint256 _amount) internal returns (uint) {
        IERC20(vcrv).safeApprove(curve, 0);
        IERC20(vcrv).safeApprove(curve, _amount);
        ICurveFi(curve).remove_liquidity(_amount, [uint256(0),0,0,0]);
    
        uint256 _vusdc = IERC20(vusdc).balanceOf(address(this));
        uint256 _vusdt = IERC20(vusdt).balanceOf(address(this));
        uint256 _vtusd = IERC20(vtusd).balanceOf(address(this));
        
        if (_vusdc > 0) {
            IERC20(vusdc).safeApprove(curve, 0);
            IERC20(vusdc).safeApprove(curve, _vusdc);
            ICurveFi(curve).exchange(1, 0, _vusdc, 0);
        }
        if (_vusdt > 0) {
            IERC20(vusdt).safeApprove(curve, 0);
            IERC20(vusdt).safeApprove(curve, _vusdt);
            ICurveFi(curve).exchange(2, 0, _vusdt, 0);
        }
        if (_vtusd > 0) {
            IERC20(vtusd).safeApprove(curve, 0);
            IERC20(vtusd).safeApprove(curve, _vtusd);
            ICurveFi(curve).exchange(3, 0, _vtusd, 0);
        }
        
        uint _before = IERC20(want).balanceOf(address(this));
        vERC20(vdai).withdraw(IERC20(vdai).balanceOf(address(this)));
        uint _after = IERC20(want).balanceOf(address(this));
        
        return _after.sub(_before);
    }
    
    function _withdrawAll() internal {
        uint _vvcrv = IERC20(vvcrv).balanceOf(address(this));
        if (_vvcrv > 0) {
            vERC20(vvcrv).withdraw(_vvcrv);
            withdrawUnderlying(IERC20(vcrv).balanceOf(address(this)));
        }
    }
    
    function _withdrawSome(uint256 _amount) internal returns (uint) {
        // calculate amount of vcrv to withdraw for amount of _want_
        uint _vcrv = _amount.mul(1e18).div(ICurveFi(curve).get_virtual_price());
        // calculate amount of vvcrv to withdraw for amount of _vcrv_
        uint _vvcrv = _vcrv.mul(1e18).div(vERC20(vvcrv).getPricePerFullShare());
        uint _before = IERC20(vcrv).balanceOf(address(this));
        vERC20(vvcrv).withdraw(_vvcrv);
        uint _after = IERC20(vcrv).balanceOf(address(this));
        return withdrawUnderlying(_after.sub(_before));
    }
    
    function balanceOfWant() public view returns (uint) {
        return IERC20(want).balanceOf(address(this));
    }
    
    function balanceOfVVCRV() public view returns (uint) {
        return IERC20(vvcrv).balanceOf(address(this));
    }
    
    function balanceOfVVCRVinVCRV() public view returns (uint) {
        return balanceOfVVCRV().mul(vERC20(vvcrv).getPricePerFullShare()).div(1e18);
    }
    
    function balanceOfVVCRVinvTUSD() public view returns (uint) {
        return balanceOfVVCRVinVCRV().mul(ICurveFi(curve).get_virtual_price()).div(1e18);
    }
    
    function balanceOfVCRV() public view returns (uint) {
        return IERC20(vcrv).balanceOf(address(this));
    }
    
    function balanceOfVCRVvTUSD() public view returns (uint) {
        return balanceOfVCRV().mul(ICurveFi(curve).get_virtual_price()).div(1e18);
    }
    
    function balanceOf() public view returns (uint) {
        return balanceOfWant()
               .add(balanceOfVVCRVinvTUSD());
    }
    
    function setGovernance(address _governance) external {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }
    
    function setController(address _controller) external {
        require(msg.sender == governance, "!governance");
        controller = _controller;
    }
}
