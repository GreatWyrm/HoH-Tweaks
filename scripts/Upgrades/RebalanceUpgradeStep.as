namespace Upgrades
{
	class RebalanceUpgradeStep : UpgradeStep
	{

		RebalanceUpgradeStep(Upgrade@ upgrade, SValue@ params, int level)
		{
			super(upgrade, params, level);
		}

		void PayForUpgrade(PlayerRecord@ record)
		{
			if (!CanAfford(record))
			{
				PrintError("Tried paying for upgrade while we can not afford the upgrade. (\"" + m_upgrade.m_id + "\" level " + m_level + ")");
				return;
			}

			bool inTown = (cast<Town>(g_gameMode) !is null);

			float payScale = PayScale(record);

			int costGold = int(int(m_costGold) * payScale);
			int costOre = int(int(m_costOre) * payScale);

			if (inTown)
			{
				auto gm = cast<Campaign>(g_gameMode);
				if (gm is null)
					return;

				gm.m_townLocal.m_gold -= costGold;
				gm.m_townLocal.m_ore -= costOre;
			}
			else
			{
				if(record !is null && record.generalStoreItemsBought == 0 && record.items.find("shopping-coupon") != -1 && costOre == 0) {
					// Item is free, do not deduct gold
				} else {
					record.runGold -= costGold;
					record.runOre -= costOre;
				}

			}

			Stats::Add("spent-gold", costGold, record);
			Stats::Add("spent-ore", costOre, record);
			Stats::Add("spent-skillpoints", m_costSkillPoints, record);
		}
	}
}
