// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IFactoryManagedUpgradeGate {
    /// @notice If an implementation is registered by the Builder DAO as an optional upgrade
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    function isRegisteredUpgradePath(address baseImpl, address upgradeImpl) external view returns (bool);

    /// @notice Called by the Builder DAO to offer implementation upgrades for created DAOs
    /// @param baseImpls The base implementation addresses
    /// @param upgradeImpl The upgrade implementation address
    function registerUpgradePath(address[] memory baseImpls, address upgradeImpl) external;

    /// @notice Called by the Builder DAO to remove an upgrade
    /// @param baseImpl The base implementation address
    /// @param upgradeImpl The upgrade implementation address
    function removeUpgradePath(address baseImpl, address upgradeImpl) external;

    event UpgradeRegistered(address baseImpl, address upgradeImpl);
    event UpgradeRemoved(address baseImpl, address upgradeImpl);
}
