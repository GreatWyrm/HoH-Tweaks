bool g_downscaling = false;

ScriptSprite@ GetFaceSprite(string charClass, int face)
{
	SValue@ svalClass = Resources::GetSValue("players/" + charClass + "/char.sval");
	if (svalClass is null)
	{
		PrintError("Couldn't get SValue file for class \"" + charClass + "\"");
		return null;
	}
	else
	{
		string faceFile = GetParamString(UnitPtr(), svalClass, "face-file", false, "gui/icons_faces.tif");
		int faceY = GetParamInt(UnitPtr(), svalClass, "face-y");
		return ScriptSprite(Resources::GetTexture2D(faceFile), vec4(face * 24, faceY, 24, 24));
	}
}

class ClassStats
{
	pfloat base_health;
	pfloat base_mana;
	pfloat base_health_regen;
	pfloat base_mana_regen;
	pfloat base_armor;
	pfloat base_resistance;

	pfloat level_health;
	pfloat level_mana;
	pfloat level_health_regen;
	pfloat level_mana_regen;
	pfloat level_armor;
	pfloat level_resistance;
}

class OwnedUpgrade
{
	string m_id;
	pint m_level;

	Upgrades::UpgradeStep@ m_step;
}

class BestiaryAttunement
{
	uint m_idHash;
	UnitProducer@ m_prod;
	int m_attuned;

	ActorItemQuality m_cachedQuality = ActorItemQuality::None;

	int GetAttuneCost(int level)
	{
		// level = the desired attunement level
		// this function must return 0 if level is 0!

		if (m_cachedQuality == ActorItemQuality::None)
		{
			auto params = m_prod.GetBehaviorParams();
			m_cachedQuality = ParseActorItemQuality(GetParamString(UnitPtr(), params, "quality", false, "common"));
		}

		switch (m_cachedQuality)
		{
			case ActorItemQuality::Common: return level * g_bestiaryCostCommon;
			case ActorItemQuality::Uncommon: return level * g_bestiaryCostUncommon;
			case ActorItemQuality::Rare: return level * g_bestiaryCostRare;
			case ActorItemQuality::Epic: return level * g_bestiaryCostEpic;
			case ActorItemQuality::Legendary: return level * g_bestiaryCostLegendary;
		}

		return level * 2;
	}
}

class OwnedItemSet
{
	ActorSet@ m_set;
	int m_count;

	OwnedItemSet(ActorSet@ itemSet)
	{
		@m_set = itemSet;
	}

	bool IsBonusActive(ActorSetBonus@ bonus)
	{
		return (m_count >= bonus.num);
	}

	bool IsAnyBonusActive()
	{
		for (uint i = 0; i < m_set.bonuses.length(); i++)
		{
			if (IsBonusActive(m_set.bonuses[i]))
				return true;
		}
		return false;
	}

	int GetNumBonusesActive()
	{
		int ret = 0;
		for (uint i = 0; i < m_set.bonuses.length(); i++)
		{
			if (IsBonusActive(m_set.bonuses[i]))
				ret++;
		}
		return ret;
	}

	ActorSetBonus@ GetBestBonus()
	{
		ActorSetBonus@ ret = null;
		for (uint i = 0; i < m_set.bonuses.length(); i++)
		{
			auto bonus = m_set.bonuses[i];
			if (IsBonusActive(bonus))
				@ret = bonus;
			else
				break;
		}
		return ret;
	}
}

enum ClassFlags
{
	Paladin = (1 << 0),
	Ranger = (1 << 1),
	Sorcerer = (1 << 2),
	Warlock = (1 << 3),
	Thief = (1 << 4),
	Priest = (1 << 5),
	Wizard = (1 << 6),
	Gladiator = (1 << 7),
	WitchHunter = (1 << 8)
}

class FountainPreset
{
	string name;
	array<uint> effects;

	void Save(SValueBuilder@ builder)
	{
		builder.PushDictionary();
		builder.PushString("name", name);
		builder.PushArray("effects");
		for (uint i = 0; i < effects.length(); i++)
			builder.PushInteger(effects[i]);
		builder.PopArray();
		builder.PopDictionary();
	}

	void Load(SValue@ data)
	{
		name = GetParamString(UnitPtr(), data, "name", false);

		effects.removeRange(0, effects.length());
		auto arrEffects = GetParamArray(UnitPtr(), data, "effects", false);
		if (arrEffects !is null)
		{
			for (uint i = 0; i < arrEffects.length(); i++)
				effects.insertLast(arrEffects[i].GetInteger());
		}
	}
}

class PlayerRecord
{
	string name; //NOTE: This can be utf8!

	// Userdata that can be used by mods. This does NOT save by itself.
	dictionary userdata;

	uint8 peer;
	uint64 id;
	Actor@ actor;
	bool local;

	bool spawnPosSaved;
	vec2 spawnPos;

	pfloat handicap;
	pint previousRun;

	pint newGamePlus;
	pint desertNewGamePlus;

	pint newGamePlusPresented;
	pint desertNewGamePlusPresented;

	pint gladiatorPoints;
	array<uint> arenaFlags;

	pint retiredAttackPower;
	pint retiredSkillPower;
	pint retiredArmor;
	pint retiredResistance;

	pint healthBonus;
	pint freeLives;
	pint freeLivesTaken;

	ClassStats classStats;
	pfloat hp;
	pfloat mana;
	bool runEnded;

	bool oneHealth;

	pint titleIndex;
	pint shortcut;

	pint runGold;
	pint runOre;
	pint curses;

	pint randomBuffNegative;
	pint randomBuffPositive;

	array<string> items;
	array<string> itemsBought;
	array<string> itemsRecycled;
	array<string> tavernDrinks;
	array<string> tavernDrinksBought;
	array<uint> temporaryBuffs;
	int potionChargesUsed;

	float driftingOffset;

	array<FountainPreset@> fountainPresets;

	array<OwnedUpgrade@> upgrades;
	array<pint> levelSkills;
	bool freeRespecUsed;
	array<pint> keys = { 0, 0, 0, 0, 0 };

	int generalStoreItemsSaved = -1;
	int generalStoreItemsPlume;
	array<uint> generalStoreItems;
	int generalStoreItemsBought;

	int sarcophagusItemsSaved = -1;
	array<uint> sarcophagusItems;

	int itemDealerSaved = -1;
	string itemDealerReward;

	array<uint> itemForgeAttuned;
	int itemForgeCrafted = -1;

	array<string> chapelUpgradesPurchased;

	array<BestiaryAttunement@> bestiaryAttunements;

	array<uint> bloodAltarRewards;

	array<uint> unlockedPets;
	uint currentPet;
	int currentPetSkin;
	array<uint> currentPetFlags;

	string charClass;
	int face;
	string voice;

	array<Materials::Dye@> colors;
	bool freeCustomizationUsed;

	uint deadTime;
	PlayerCorpse@ corpse;
	array<int> soulLinks;
	int soulLinkedBy = -1;

	int revealDesertExit;

	pint armor;
	ArmorDef@ armorDef;
	pint64 experience;
	pint level;

	uint team;
	pint kills;
	pint killsTotal;
	pint deaths;
	pint deathsTotal;

	pint pickups;
	pint pickupsTotal;

	bool readyState;
	pint pingCount;

	Stats::StatList@ statistics;
	Stats::StatList@ statisticsSession;

	Modifiers::ModifierList@ modifiers;
	Modifiers::ModifierList@ modifiersItems;
	Modifiers::ModifierList@ modifiersSkills;
	Modifiers::ModifierList@ modifiersUpgrades;
	Modifiers::ModifierList@ modifiersBuffs;
	Modifiers::ModifierList@ modifiersTitles;
	Modifiers::ModifierList@ modifiersDrinks;
	Modifiers::ModifierList@ modifiersStatues;
	Modifiers::ModifierList@ modifiersBloodAltar;

	array<OwnedItemSet@> ownedItemSets;

	BitmapString@ playerNameText;

	PlayerRecord()
	{
		mana = 1.0;
		handicap = 0.8;

		voice = "default";

		ResetLevelSkills();

		@statistics = Stats::LoadList("tweak/stats.sval");
		@statisticsSession = Stats::LoadList("tweak/stats.sval");

		@modifiersItems = Modifiers::ModifierList();
		@modifiersSkills = Modifiers::ModifierList();
		@modifiersUpgrades = Modifiers::ModifierList();
		@modifiersBuffs = Modifiers::ModifierList();
		@modifiersTitles = Modifiers::ModifierList("titles");
		@modifiersDrinks = Modifiers::ModifierList();
		@modifiersStatues = Modifiers::ModifierList();
		@modifiersBloodAltar = Modifiers::ModifierList();

		@modifiers = Modifiers::ModifierList();
		modifiers.Add(modifiersItems);
		modifiers.Add(modifiersSkills);
		modifiers.Add(modifiersUpgrades);
		modifiers.Add(modifiersBuffs);
		modifiers.Add(modifiersTitles);
		modifiers.Add(modifiersDrinks);
		modifiers.Add(modifiersStatues);
		modifiers.Add(modifiersBloodAltar);

		modifiersItems.m_name = Resources::GetString(".modifier.list.player.items");
		modifiersSkills.m_name = Resources::GetString(".modifier.list.player.skills");
		modifiersUpgrades.m_name = Resources::GetString(".modifier.list.player.upgrades");
		modifiersBuffs.m_name = Resources::GetString(".modifier.list.player.buffs");
		modifiersTitles.m_name = Resources::GetString(".modifier.list.player.titles");
		modifiersDrinks.m_name = Resources::GetString(".modifier.list.player.tavern_drinks");
		modifiersStatues.m_name = Resources::GetString(".modifier.list.player.statues");
		modifiersBloodAltar.m_name = Resources::GetString(".modifier.list.player.bloodaltar");
	}

	void EnableItemModifiers(bool enable)
	{
		if (enable)
		{
			if (!modifiers.Has(modifiersItems))
				modifiers.Add(modifiersItems);
		}
		else
		{
			modifiers.Remove(modifiersItems);

			// Workaround for Remove() not removing the list from its internal list
			int index = modifiers.m_modifiers.findByRef(modifiersItems);
			modifiers.m_modifiers.removeAt(index);
		}
	}

	bool IsPetUnlocked(Pets::PetDef@ pet)
	{
		if (pet is null)
			return true;

		return unlockedPets.find(pet.m_idHash) != -1;
	}

	void UnlockPet(Pets::PetDef@ pet)
	{
		if (pet is null)
			return;

		if (unlockedPets.find(pet.m_idHash) == -1)
			unlockedPets.insertLast(pet.m_idHash);
	}

	void RefillPotionCharges()
	{
		potionChargesUsed = 0;

		auto player = cast<PlayerBase>(actor);
		if (player !is null)
			player.OnPotionCharged();
	}

	void GivePotionCharges(int num)
	{
		potionChargesUsed = max(0, potionChargesUsed - num);

		auto player = cast<PlayerBase>(actor);
		if (player !is null)
			player.OnPotionCharged();
	}

	BestiaryAttunement@ GetBestiaryAttunement(uint prodHash)
	{
		for (uint i = 0; i < bestiaryAttunements.length(); i++)
		{
			auto ba = bestiaryAttunements[i];
			if (ba.m_idHash == prodHash)
				return ba;
		}

		auto prod = Resources::GetUnitProducer(prodHash);
		if (prod is null)
			return null;

		auto ba = BestiaryAttunement();
		ba.m_idHash = prodHash;
		@ba.m_prod = prod;
		ba.m_attuned = 0;
		bestiaryAttunements.insertLast(ba);
		return ba;
	}

	void RevealDesertExit()
	{
		if (revealDesertExit > 0)
			return;

		int exit = 0;
		if (g_flags.IsSet("desert_exit_west")) exit = 1;
		else if (g_flags.IsSet("desert_exit_north")) exit = 2;
		else if (g_flags.IsSet("desert_exit_east")) exit = 3;
		else exit = 4;
		RevealDesertExit(exit);
	}

	void RevealDesertExit(int exit)
	{
		revealDesertExit = exit;

		auto hud = GetHUD();
		if (hud !is null && local)
		{
			TopNumberIconWidget@ wTopNumber;
			switch (exit)
			{
				case 1:
					@wTopNumber = hud.SetTopNumberIcon("desert-west");
					revealDesertExit = 1;
					break;

				case 2:
					@wTopNumber = hud.SetTopNumberIcon("desert-north");
					revealDesertExit = 2;
					break;

				case 3:
					@wTopNumber = hud.SetTopNumberIcon("desert-east");
					revealDesertExit = 3;
					break;

				default:
					PrintError("Exit location is unknown, unable to set desert exit.");
					@wTopNumber = hud.SetTopNumberIcon("error");
					revealDesertExit = 4;
					break;
			}

			if (wTopNumber !is null)
				wTopNumber.m_shouldSave = false;
		}
	}

	Modifiers::ModifierList@ GetModifiers()
	{
		if (local)
			return g_allModifiers;
		return modifiers;
	}

	int GladiatorRank(int pointOffset = 0)
	{
		return int((gladiatorPoints + pointOffset) / Tweak::PointsPerGladiatorRank);
	}

	void GiveGladiatorPoints(int amount)
	{
		// Discard excess points
		int lowAmount = gladiatorPoints % Tweak::PointsPerGladiatorRank;
		if (lowAmount + amount > Tweak::PointsPerGladiatorRank)
			gladiatorPoints += Tweak::PointsPerGladiatorRank - lowAmount;
		else
			gladiatorPoints += amount;
	}

	int GetTotalSwordTokens(int rank = -1)
	{
		if (rank == -1)
			rank = GladiatorRank();

		return 5 * rank;
	}

	int GetSpentSwordTokens()
	{
		int ret = 0;
		ret += retiredAttackPower;
		ret += retiredSkillPower;
		ret += retiredArmor;
		ret += retiredResistance;
		return ret;
	}

	int GetAvailableSwordTokens()
	{
		return GetTotalSwordTokens() - GetSpentSwordTokens();
	}

	int EffectiveLevel()
	{
		if (!g_downscaling)
			return level;

		return min(level, GetLevelCap(true));
	}

	void ResetLevelSkills()
	{
		levelSkills = { 1, 1, 0, 0, 0, 0, 0 };
	}

	void ClearSkillUpgrades()
	{
		ResetLevelSkills();
		for (int i = int(upgrades.length() - 1); i >= 0; i--)
		{
			if (cast<Upgrades::RecordUpgradeStep>(upgrades[i].m_step) !is null)
				upgrades.removeAt(i);
		}
	}

	uint GetCharFlags()
	{
		if (charClass == "paladin")
			return uint(ClassFlags::Paladin);
		else if (charClass == "ranger")
			return uint(ClassFlags::Ranger);
		else if (charClass == "sorcerer")
			return uint(ClassFlags::Sorcerer);
		else if (charClass == "warlock")
			return uint(ClassFlags::Warlock);
		else if (charClass == "thief")
			return uint(ClassFlags::Thief);
		else if (charClass == "priest")
			return uint(ClassFlags::Priest);
		else if (charClass == "wizard")
			return uint(ClassFlags::Wizard);
		else if (charClass == "gladiator")
			return uint(ClassFlags::Gladiator);
		else if (charClass == "witch_hunter")
			return uint(ClassFlags::WitchHunter);
		return 0;
	}

	OwnedItemSet@ GetOwnedItemSet(ActorSet@ itemSet)
	{
		for (uint i = 0; i < ownedItemSets.length(); i++)
		{
			auto ownedSet = ownedItemSets[i];
			if (ownedSet.m_set is itemSet)
				return ownedSet;
		}
		return null;
	}

	void RefreshItemSets()
	{
		ownedItemSets.removeRange(0, ownedItemSets.length());

		for (uint i = 0; i < items.length(); i++)
		{
			auto item = g_items.GetItem(items[i]);
			if (item is null)
			{
				PrintError("Couldn't find item with ID \"" + items[i] + "\"!");
				continue;
			}

			if (item.set is null)
				continue;

			OwnedItemSet@ ownedSet = GetOwnedItemSet(item.set);
			if (ownedSet is null)
			{
				@ownedSet = OwnedItemSet(item.set);
				ownedItemSets.insertLast(ownedSet);
			}
			ownedSet.m_count++;
		}
		if(items.find("shifting-clay") != -1) {
			for(uint i = 0; i < ownedItemSets.length(); i++)
			{
				ownedItemSets[i].m_count++;
			}
		}
	}

	void RefreshModifiers()
	{
		modifiers.m_name = GetName();

		// Modifiers for tavern drinks
		modifiersDrinks.Clear();

		for (uint j = 0; j < tavernDrinks.length(); j++)
		{
			auto drink = GetTavernDrink(HashString(tavernDrinks[j]));
			for (uint i = 0; i < drink.modifiers.length(); i++)
				modifiersDrinks.Add(drink.modifiers[i]);
		}

		// Modifiers for items
		modifiersItems.Clear();

		for (uint j = 0; j < items.length(); j++)
		{
			auto item = g_items.GetItem(items[j]);
			for (uint i = 0; i < item.modifiers.length(); i++)
			{
				modifiersItems.Add(item.modifiers[i]);

				// If item is attuned, double it
				if (itemForgeAttuned.find(item.idHash) != -1)
				{
					modifiersItems.Add(item.modifiers[i]);

					// If double attunement fountain effect is on, triple it
					if (Fountain::HasEffect("double_attunement"))
						modifiersItems.Add(item.modifiers[i]);
				}
			}
		}

		// Modifiers for item sets
		RefreshItemSets();
		for (uint j = 0; j < ownedItemSets.length(); j++)
		{
			auto bestBonus = ownedItemSets[j].GetBestBonus();
			if (bestBonus !is null)
			{
				for (uint i = 0; i < bestBonus.modifiers.length(); i++)
					modifiersItems.Add(bestBonus.modifiers[i]);
			}
		}

		// Modifiers for purchased upgrades
		modifiersUpgrades.Clear();
		for (uint j = 0; j < upgrades.length(); j++)
		{
			auto step = cast<Upgrades::ModifierUpgradeStep>(upgrades[j].m_step);
			if (step is null)
				continue;

			auto mods = step.GetModifiers();
			for (uint i = 0; i < mods.length(); i++)
				modifiersUpgrades.Add(mods[i]);
		}

		// Modifiers from retired gladiator upgrades
		RefreshRetiredModifiers();

		// Modifiers from statues
		modifiersStatues.Clear();
		auto gm = cast<Campaign>(g_gameMode);
		if (gm !is null)
		{
			auto town = gm.m_town;
			if (Network::IsServer())
				@town = gm.m_townLocal;

			if (town !is null)
			{
				auto statues = town.GetPlacedStatues();
				for (uint i = 0; i < statues.length(); i++)
				{
					auto townStatue = statues[i];
					auto statueDef = townStatue.GetDef();
					statueDef.EnableModifiers(modifiersStatues, townStatue.m_level);
				}
			}
		}

		// Modifiers for blood altar rewards
		modifiersBloodAltar.Clear();
		for (uint i = 0; i < bloodAltarRewards.length(); i++)
		{
			auto reward = BloodAltar::GetReward(bloodAltarRewards[i]);
			if (reward is null)
				continue;

			for (uint j = 0; j < reward.modifiers.length(); j++)
				modifiersBloodAltar.Add(reward.modifiers[j]);
		}

		if (bloodAltarRewards.length() > 0)
		{
			SValueBuilder builder;
			builder.PushDictionary();
			builder.PushFloat("mul", pow(0.9f, bloodAltarRewards.length()));
			modifiersBloodAltar.Add(Modifiers::MaxHealth(UnitPtr(), builder.Build()));
		}

		RefreshModifiersBuffs();

		// Not really a modifier, but it fits here
		oneHealth = Fountain::HasEffect("1_hp");
	}

	void RefreshSkillModifiers()
	{
		// NOTE: This is separate from RefreshModifiers because it can create an instance of a modifier that
		//       is also a buff widget info. If that is cloned it will duplicate the buff icon in the HUD with
		//       a frozen state. We don't want that, so we just refresh the skill modifiers on a need-to basis.
		//
		//       A better fix for the above problem is to create a "ModifierRefresher" class that automatically
		//       merges modifiers in a list, which would avoid removing and re-adding a modifier if there were
		//       no changes, and could keep existing instances of modifiers. I didn't implement that when fixing
		//       this because I'm unsure about the performance this would gain and/or take.
		//
		// ModifierRefresher refresher(modifiersSkills);
		// foreach (modifier)
		//   refresher.Add(modifier);
		// refresher.Finish();
		//

		// Modifiers for skills
		auto player = cast<PlayerBase>(actor);
		if (player !is null)
		{
			modifiersSkills.Clear();
			for (uint j = 0; j < player.m_skills.length(); j++)
			{
				auto mods = player.m_skills[j].GetModifiers();
				if (mods is null)
					continue;

				for (uint i = 0; i < mods.length(); i++)
					modifiersSkills.Add(mods[i]);
			}
		}
	}

	void LoadRetiredModifiers(array<Modifiers::Modifier@> mods, int level)
	{
		if (level == 0)
			return;

		for (uint i = 0; i < mods.length(); i++)
		{
			auto mod = mods[i];
			auto stackedMod = cast<Modifiers::StackedModifier>(modifiersUpgrades.Add(mod));
			if (stackedMod !is null)
				stackedMod.m_stackCount = level;
			else
			{
				for (int j = 1; j < level; j++)
					modifiersUpgrades.Add(mod);
			}
		}
	}

	void RefreshRetiredModifiers()
	{
		auto svalModifier = Resources::GetSValue("tweak/retiredgladiator.sval");

		LoadRetiredModifiers(Modifiers::LoadModifiers(UnitPtr(), svalModifier, "attack-power-"), retiredAttackPower);
		LoadRetiredModifiers(Modifiers::LoadModifiers(UnitPtr(), svalModifier, "skill-power-"), retiredSkillPower);
		LoadRetiredModifiers(Modifiers::LoadModifiers(UnitPtr(), svalModifier, "armor-"), retiredArmor);
		LoadRetiredModifiers(Modifiers::LoadModifiers(UnitPtr(), svalModifier, "resistance-"), retiredResistance);
	}

	void RefreshModifiersBuffs()
	{
		modifiersBuffs.Clear();
		modifiersBuffs.Add(Modifiers::RandomBuff(randomBuffPositive, randomBuffNegative));
	}

	float GetHandicap()
	{
		if (g_players.length() == 1)
			return handicap;
		return 0.0f;
	}

	Titles::Title@ GetTitle()
	{
		return g_classTitles.GetTitle(charClass, titleIndex);
	}

	void GiveTitle(int index)
	{
		if (index <= titleIndex)
			return;

		titleIndex = index;
		OnNewTitle();
	}

	void OnNewTitle()
	{
		print("New class title: \"" + GetTitle().m_name + "\"");

		auto player = cast<Player>(actor);
		if (player !is null)
			player.OnNewTitle(GetTitle());
	}

	void AssignUnit(UnitPtr unit)
	{
		@actor = cast<Actor>(unit.GetScriptBehavior());
	}

	int MaxHealth()
	{
		if (oneHealth)
			return 1;

		return int(classStats.base_health + float(EffectiveLevel() -1) * classStats.level_health);
	}

	int MaxMana() { return int(classStats.base_mana + float(EffectiveLevel() -1) * classStats.level_mana); }
	float HealthRegen() { return classStats.base_health_regen + float(EffectiveLevel() -1) * classStats.level_health_regen; }
	float ManaRegen() { return classStats.base_mana_regen + float(EffectiveLevel() -1) * classStats.level_mana_regen; }
	float Armor() { return classStats.base_armor + float(EffectiveLevel() -1) * classStats.level_armor; }
	float Resistance() { return classStats.base_resistance + float(EffectiveLevel() -1) * classStats.level_resistance; }

	int GetFreeLives() { return 0; }

	int64 LevelExperience(int atLevel)
	{
		return int64(Tweak::ExperiencePerLevel * pow2(atLevel, Tweak::ExperienceExponent));
	}

	void NetSyncExperience(int lvl, int64 exp)
	{
		level = lvl;
		experience = exp;
	}

	int GetTotalSkillpoints()
	{
		int ret = 0;

		for (int i = 1; i < level; i++)
			ret += min(Tweak::SkillPointsPerLevelCap, Tweak::SkillPointsPerLevelBase + int(i / Tweak::SkillPointsPerLevelMod));

		auto gm = cast<Campaign>(g_gameMode);
		auto townTitle = gm.m_townLocal.GetTitle();
		for (uint i = 0; i < gm.m_titlesGuild.m_titles.length(); i++)
		{
			auto title = gm.m_titlesGuild.m_titles[i];
			if (townTitle.m_points >= title.m_points)
				ret += title.m_skillPoints;
			else
				break;
		}

		ret += desertNewGamePlus * Tweak::DesertNewGamePlusStars;

		return ret;
	}

	int GetSpentSkillpoints()
	{
		int ret = 0;

		for (uint i = 0; i < itemForgeAttuned.length(); i++)
		{
			auto item = g_items.GetItem(itemForgeAttuned[i]);
			if (item !is null)
				ret += GetItemAttuneCost(item);
		}

		for (uint i = 0; i < upgrades.length(); i++)
		{
			auto ownedUpgrade = upgrades[i];
			auto upgrade = ownedUpgrade.m_step.m_upgrade;
			for (uint j = 0; j < upgrade.m_steps.length(); j++)
			{
				auto step = upgrade.m_steps[j];
				if (ownedUpgrade.m_level >= step.m_level)
					ret += upgrade.m_steps[j].m_costSkillPoints;
			}
		}

		for (uint i = 0; i < bestiaryAttunements.length(); i++)
		{
			auto entry = bestiaryAttunements[i];
			for (int j = 1; j <= entry.m_attuned; j++)
				ret += entry.GetAttuneCost(j);
		}

		return ret;
	}

	int GetAvailableSkillpoints()
	{
		return GetTotalSkillpoints() - GetSpentSkillpoints();
	}

	int GetLevelCap(bool useCurrentNgp = false)
	{
		float ngp = float(int(newGamePlus));

		if (useCurrentNgp)
			ngp = min(g_ngp, float(newGamePlus));

		return 20 + int(ngp * 5.0f);
	}

	bool CanGetExperience()
	{
		auto gm = cast<Campaign>(g_gameMode);
		if (!gm.CanGetExperience())
			return false;

		return level < GetLevelCap();
	}

	void GiveExperience(int64 amount)
	{
		if (amount <= 0)
			return;

		int64 xpNeeded = 0;
		int64 xpAdded = amount;
		int64 levelsAdded = 0;

		Stats::Add("exp-gained", amount, this);
		Stats::Add("avg-exp-gained", amount, this);

		while (true)
		{
			if (!CanGetExperience())
				break;
		
			xpNeeded = LevelExperience(level);

			if (experience + xpAdded >= xpNeeded)
			{
				int64 add = xpNeeded - experience;
				experience += add;

				xpAdded -= add;
				
				level++;
				levelsAdded++;
			}
			else
			{
				experience += xpAdded;
				break;
			}
		}

		if (local)
		{
			(Network::Message("PlayerSyncExperience") << level).AddLong(experience).SendToAll();

			if (levelsAdded > 0)
			{
				if (actor !is null)
					cast<Player>(actor).OnLevelUp(levelsAdded);
				
				if (level >= 20)
					Platform::Service.UnlockAchievement("level20_" + charClass);
				if (level >= 40)
					Platform::Service.UnlockAchievement("level40_" + charClass);
			}
		}
	}

	string GetLobbyName()
	{
		return Lobby::GetPlayerName(peer);
	}

	string GetName()
	{
		/*if (Platform::GetSessionCount() == 1)
			return Lobby::GetPlayerName(peer);

		return "player " + (peer + 1);*/
		return name;
	}

	int GetPing() { return Lobby::GetPlayerPing(peer); }

	bool IsDead()
	{
		return deadTime > 0 && actor is null;
	}

	int CurrentHealth()
	{
		ivec2 extraStats;
		float mul = 1.0f;

		auto localPlayer = cast<Player>(actor);
		if (localPlayer !is null)
		{
			extraStats = g_allModifiers.StatsAdd(localPlayer);
			mul = g_allModifiers.MaxHealthMul(localPlayer);
		}

		float maxHp = (MaxHealth() + extraStats.x) * mul;

		return int(ceil(hp * maxHp));
	}

	int CurrentMana()
	{
		ivec2 extraStats;

		auto localPlayer = cast<Player>(actor);
		if (localPlayer !is null)
			extraStats = g_allModifiers.StatsAdd(localPlayer);

		return int(floor(mana * (MaxMana() + extraStats.y)));
	}

	float CurrentHealthScalar()
	{
		return hp;
	}

	bool HasBeenDeadFor(uint ms)
	{
		if (!IsDead())
			return false;

		return (deadTime + ms) < g_scene.GetTime();
	}
	
	void GiveCurse(int amount)
	{
		curses += amount;
		if (curses < 0)
		{
			amount -= 0 - curses;
			curses = 0;
		}

		if (amount > 0)
			Stats::Add("curses-received", amount, this);
		else if (amount < 0)
			Stats::Add("curses-removed", -amount, this);

		if (amount > 0 && actor !is null)
			PlayEffect("effects/curse_gain.effect", actor.m_unit.GetPosition());
	}

	int opCmp(const PlayerRecord &in other)
	{
		if (peer < other.peer) return -1;
		else if (peer > other.peer) return 1;
		return 0;
	}

	float FetchFloatProd(string name = "") { return 1.0; }
	float FetchFloatSum(string name = "") { return 0.0; }
	int FetchIntSum(string name = "") { return 0; }
	bool FetchBoolAny(string name = "") { return false; }
	array<string> FetchArrayString(string name = "") { return array<string>(); }

	OwnedUpgrade@ GetOwnedUpgrade(string id)
	{
		for (uint i = 0; i < upgrades.length(); i++)
		{
			if (upgrades[i].m_id == id)
				return upgrades[i];
		}
		return null;
	}

	OwnedUpgrade@ GetOwnedUpgrade(uint idHash)
	{
		for (uint i = 0; i < upgrades.length(); i++)
		{
			//TODO: Add m_idHash to OwnedUpgrade?
			if (HashString(upgrades[i].m_id) == idHash)
				return upgrades[i];
		}
		return null;
	}
}
