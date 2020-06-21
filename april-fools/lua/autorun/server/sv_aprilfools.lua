if not sql.TableExists("aprilfools_pranked") then
	local query = "CREATE TABLE aprilfools_pranked (steamid string)"
	sql.Query(query)
end

hook.Add( "CheckPassword", "CheckingThePassword", function(steamid)
	local thetime = os.time()
	local thedate = os.date("%d-%m", thetime)
	if thedate ~= "01-04" then return end -- Has the be April 1st
	local query = "SELECT * FROM aprilfools_pranked WHERE steamid='"..steamid.."'"
	local result = sql.Query(query)
	if result and #result >= 0 then 
		return
	end
	sql.Query("INSERT INTO aprilfools_pranked VALUES ('"..steamid.."')")
	return false, "You cannot connect to the selected server, because it is running in VAC (Valve Anti-Cheat) secure mode.\r\n\r\nThis Steam account has been banned from secure servers due to a cheating infraction."
end)