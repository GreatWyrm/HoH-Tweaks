namespace Upgrades
{
	class UpgradeStep
	{
		Upgrade@ m_upgrade;

		pint m_costGold;
		pint m_costOre;
		pint m_costSkillPoints;

		string m_name;
		string m_description;
		ScriptSprite@ m_sprite;

		int m_level;

		int m_restrictShopLevelMin;
		int m_restrictShopLevelMax;
		int m_restrictPlayerLevelMin;
		string m_restrictFlag;

		UpgradeStep(Upgrade@ upgrade, SValue@ params, int level)
		{
			@m_upgrade = upgrade;

			m_costGold = GetParamInt(UnitPtr(), params, "cost-gold", false);
			m_costOre = GetParamInt(UnitPtr(), params, "cost-ore", false);
			m_costSkillPoints = GetParamInt(UnitPtr(), params, "cost-skillpoints", false);

			m_name = GetParamString(UnitPtr(), params, "name", false);
			m_description = GetParamString(UnitPtr(), params, "desc", false);

			auto arrSprite = GetParamArray(UnitPtr(), params, "icon", false);
			if (arrSprite !is null)
				@m_sprite = ScriptSprite(arrSprite);

			m_level = GetParamInt(UnitPtr(), params, "level", false, level);

			m_restrictShopLevelMin = GetParamInt(UnitPtr(), params, "restrict-shop-level-min", false, -1);
			m_restrictShopLevelMax = GetParamInt(UnitPtr(), params, "restrict-shop-level-max", false, -1);
			m_restrictPlayerLevelMin = GetParamInt(UnitPtr(), params, "restrict-player-level-min", false, -1);
			m_restrictFlag = GetParamString(UnitPtr(), params, "restrict-flag", false, "");
		}

		string GetButtonText()
		{
			return Resources::GetString(m_name);
		}

		string GetTooltipTitle()
		{
			return Resources::GetString(m_name);
		}

		string GetTooltipDescription()
		{
			return Resources::GetString(m_description);
		}

		ScriptSprite@ GetSprite()
		{
			if (m_sprite is null)
				return m_upgrade.m_sprite;
			return m_sprite;
		}

		void DrawShopIcon(Widget@ widget, SpriteBatch& sb, vec2 pos, vec2 size, vec4 color)
		{
		}

		bool IsOwned(PlayerRecord@ record)
		{
			for (uint i = 0; i < record.upgrades.length(); i++)
			{
				auto ownedUpgrade = record.upgrades[i];
				if (ownedUpgrade.m_id == m_upgrade.m_id && ownedUpgrade.m_level >= m_level)
					return true;
			}
			return false;
		}

		bool IsRestricted()
		{
			return false;
		}

		bool CanAfford(PlayerRecord@ record)
		{
			bool inTown = (cast<Town>(g_gameMode) !is null);

			float payScale = PayScale(record);

			int costGold = int(int(m_costGold) * payScale);
			int costOre = int(int(m_costOre) * payScale);

			if (inTown)
			{
				auto gm = cast<Campaign>(g_gameMode);
				if (gm is null)
					return false;

				if (costGold > 0 && costGold > gm.m_townLocal.m_gold)
					return false;

				if (costOre > 0 && costOre > gm.m_townLocal.m_ore)
					return false;
			}
			else
			{
				if (costGold > 0 && costGold > record.runGold)
					return false;

				if (costOre > 0 && costOre > record.runOre)
					return false;
			}

			if (m_costSkillPoints > 0 && m_costSkillPoints > record.GetAvailableSkillpoints())
				return false;

			return true;
		}

		float PayScale(PlayerRecord@ record)
		{
			return 1.0f;
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

		bool BuyNow(PlayerRecord@ record)
		{
			return ApplyNow(record);
		}

		bool ApplyNow(PlayerRecord@ record)
		{
			return false;
		}
	}
}