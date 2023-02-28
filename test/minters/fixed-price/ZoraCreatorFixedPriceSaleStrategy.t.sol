// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {ZoraCreator1155Impl} from "../../../src/nft/ZoraCreator1155Impl.sol";
import {ZoraCreator1155Proxy} from "../../../src/proxies/ZoraCreator1155Proxy.sol";
import {IZoraCreator1155} from "../../../src/interfaces/IZoraCreator1155.sol";
import {IRenderer1155} from "../../../src/interfaces/IRenderer1155.sol";
import {ICreatorRoyaltiesControl} from "../../../src/interfaces/ICreatorRoyaltiesControl.sol";
import {IZoraCreator1155Factory} from "../../../src/interfaces/IZoraCreator1155Factory.sol";
import {ZoraCreatorFixedPriceSaleStrategy} from "../../../src/minters/fixed-price/ZoraCreatorFixedPriceSaleStrategy.sol";

contract ZoraCreatorFixedPriceSaleStrategyTest is Test {
    ZoraCreator1155Impl internal target;
    ZoraCreatorFixedPriceSaleStrategy internal fixedPrice;
    address internal admin = address(0x999);

    event SaleSet(address mediaContract, uint256 tokenId, ZoraCreatorFixedPriceSaleStrategy.SalesConfig salesConfig);

    function setUp() external {
        bytes[] memory emptyData = new bytes[](0);
        ZoraCreator1155Impl targetImpl = new ZoraCreator1155Impl(0, address(0));
        ZoraCreator1155Proxy proxy = new ZoraCreator1155Proxy(address(targetImpl));
        target = ZoraCreator1155Impl(address(proxy));
        target.initialize("test", ICreatorRoyaltiesControl.RoyaltyConfiguration(0, 0, address(0)), admin, emptyData);
        fixedPrice = new ZoraCreatorFixedPriceSaleStrategy();
    }

    function test_ContractName() external {
        assertEq(fixedPrice.contractName(), "Fixed Price Sale Strategy");
    }

    function test_Version() external {
        assertEq(fixedPrice.contractVersion(), "0.0.1");
    }

    function test_PurchaseFlow() external {
        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        vm.expectEmit(false, false, false, false);
        emit SaleSet(
            address(target),
            newTokenId,
            ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                pricePerToken: 1 ether,
                saleStart: 0,
                saleEnd: type(uint64).max,
                maxTokensPerAddress: 0,
                fundsRecipient: address(0)
            })
        );
        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 0,
                    fundsRecipient: address(0)
                })
            )
        );
        vm.stopPrank();

        address tokenRecipient = address(322);
        vm.deal(tokenRecipient, 20 ether);

        vm.startPrank(tokenRecipient);
        target.purchase{value: 10 ether}(fixedPrice, newTokenId, 10, abi.encode(tokenRecipient));

        assertEq(target.balanceOf(tokenRecipient, newTokenId), 10);
        assertEq(address(target).balance, 10 ether);

        vm.stopPrank();
    }

    function test_SaleStart() external {
        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: uint64(block.timestamp + 1 days),
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 0,
                    fundsRecipient: address(0)
                })
            )
        );
        vm.stopPrank();

        address tokenRecipient = address(322);
        vm.deal(tokenRecipient, 20 ether);

        vm.expectRevert(abi.encodeWithSignature("SaleHasNotStarted()"));
        vm.prank(tokenRecipient);
        target.purchase{value: 10 ether}(fixedPrice, newTokenId, 10, abi.encode(tokenRecipient));
    }

    function test_SaleEnd() external {
        vm.warp(2 days);

        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: uint64(1 days),
                    maxTokensPerAddress: 0,
                    fundsRecipient: address(0)
                })
            )
        );
        vm.stopPrank();

        address tokenRecipient = address(322);
        vm.deal(tokenRecipient, 20 ether);

        vm.expectRevert(abi.encodeWithSignature("SaleEnded()"));
        vm.prank(tokenRecipient);
        target.purchase{value: 10 ether}(fixedPrice, newTokenId, 10, abi.encode(tokenRecipient));
    }

    function test_MaxTokensPerAddress() external {
        vm.warp(2 days);

        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 5,
                    fundsRecipient: address(0)
                })
            )
        );
        vm.stopPrank();

        address tokenRecipient = address(322);
        vm.deal(tokenRecipient, 20 ether);

        vm.prank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSignature("MintedTooManyForAddress()"));
        target.purchase{value: 6 ether}(fixedPrice, newTokenId, 6, abi.encode(tokenRecipient));
    }

    function test_PricePerToken() external {
        vm.warp(2 days);

        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 0,
                    fundsRecipient: address(0)
                })
            )
        );
        vm.stopPrank();

        address tokenRecipient = address(322);
        vm.deal(tokenRecipient, 20 ether);

        vm.startPrank(tokenRecipient);
        vm.expectRevert(abi.encodeWithSignature("WrongValueSent()"));
        target.purchase{value: 0.9 ether}(fixedPrice, newTokenId, 1, abi.encode(tokenRecipient));
        vm.expectRevert(abi.encodeWithSignature("WrongValueSent()"));
        target.purchase{value: 1.1 ether}(fixedPrice, newTokenId, 1, abi.encode(tokenRecipient));
        target.purchase{value: 1 ether}(fixedPrice, newTokenId, 1, abi.encode(tokenRecipient));
        vm.stopPrank();
    }

    function test_FundsRecipient() external {
        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        target.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                    pricePerToken: 1 ether,
                    saleStart: 0,
                    saleEnd: type(uint64).max,
                    maxTokensPerAddress: 0,
                    fundsRecipient: address(1)
                })
            )
        );
        vm.stopPrank();

        address tokenRecipient = address(322);
        vm.deal(tokenRecipient, 20 ether);
        vm.prank(tokenRecipient);
        target.purchase{value: 10 ether}(fixedPrice, newTokenId, 10, abi.encode(tokenRecipient));

        assertEq(address(1).balance, 10 ether);
    }

    function test_ResetSale() external {
        vm.startPrank(admin);
        uint256 newTokenId = target.setupNewToken("https://zora.co/testing/token.json", 10);
        target.addPermission(newTokenId, address(fixedPrice), target.PERMISSION_BIT_MINTER());
        vm.expectEmit(false, false, false, false);
        emit SaleSet(
            address(target),
            newTokenId,
            ZoraCreatorFixedPriceSaleStrategy.SalesConfig({pricePerToken: 0, saleStart: 0, saleEnd: 0, maxTokensPerAddress: 0, fundsRecipient: address(0)})
        );
        target.callSale(newTokenId, fixedPrice, abi.encodeWithSelector(ZoraCreatorFixedPriceSaleStrategy.resetSale.selector, newTokenId));
        vm.stopPrank();

        ZoraCreatorFixedPriceSaleStrategy.SalesConfig memory sale = fixedPrice.sale(address(target), newTokenId);
        assertEq(sale.pricePerToken, 0);
        assertEq(sale.saleStart, 0);
        assertEq(sale.saleEnd, 0);
        assertEq(sale.maxTokensPerAddress, 0);
        assertEq(sale.fundsRecipient, address(0));
    }
}
