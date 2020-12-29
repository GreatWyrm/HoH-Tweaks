namespace HoHTweaks
{
    [Hook]
    void PlayerRecordRefreshItemSets(PlayerRecord@ record)
    {
        if(record.items.find("shifting-clay") != -1) {
            for(uint i = 0; i < record.ownedItemSets.length(); i++) {
                record.ownedItemSets[i].m_count++;
            }
        }
    }
}