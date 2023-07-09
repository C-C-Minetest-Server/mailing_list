if not mail.registered_on_send then
	error("Please use C&C Server's fork of mail mod.")
end

local MN = minetest.get_current_modname()
local WP = minetest.get_worldpath()
local DB = WP .. "/mailing_list.db"
local S = minetest.get_translator(MN)

-- minetest.safe_file_write(path, content)
-- minetest.serialize(table)
-- minetest.deserialize(string[, safe])

mailing_list = {}
mailing_list.lists = {}
mailing_list.PREFIX = "ml."

local function log(level,msg)
	if not msg then
		msg = level
		level = "action"
	end
	minetest.log(level,"[mailing_list] " .. msg)
end

local function list2spacesep(list)
	local RSTR = ""
	for _,y in ipairs(list) do
		RSTR = RSTR .. y .. " "
	end
	return RSTR
end

function mailing_list.load()
	log("Loading data...")
	local file = io.open(DB,"r")
	if file then
		local data_str = file:read("*a")
		mailing_list.lists = minetest.deserialize(data_str,true) or {}
	else
		mailing_list.lists = {}
	end
end

function mailing_list.save()
	log("Saving data...")
	local data_str = minetest.serialize(mailing_list.lists)
	minetest.safe_file_write(DB,data_str)
end
local save = mailing_list.save

mailing_list.load()

local _ = S("Exists")
function mailing_list.register_mailing_list(list)
	if not mailing_list.lists[list] then
		log("action","Registering mailing list `" .. list .."`")
		mailing_list.lists[list] = {}
		save()
		return true
	else
		log("warning","Mailing list `" .. list .. "` exists, not registering.")
		return false, "Exists"
	end
end

local _ = S("Mailing list not found")
function mailing_list.add_mailing_list_member(list,members)
	if not members then
		members = {}
	end
	if mailing_list.lists[list] then
		log("action","Adding members to mailing list `" .. list .. "`. Additional members: " .. list2spacesep(members))
		for x,y in ipairs(members) do
			mailing_list.lists[list][y] = true
		end
		save()
		return true
	else
		log("error","Mailing list `" .. list .. "` does not exists, not adding members.")
		return false, "Mailing list not found"
	end
end

function mailing_list.remove_mailing_list_member(list,members)
	if not members then
		members = {}
	end
	if mailing_list.lists[list] then
		log("action","Removing members to mailing list `" .. list .. "`. Removing members: " .. list2spacesep(members))
		for _,y in ipairs(members) do
			mailing_list.lists[list][y] = nil
		end
		save()
		return true
	else
		log("error","Mailing list `" .. list .. "` does not exists, not adding members.")
		return false, "Mailing list not found"
	end
end

function mailing_list.unregister_mailing_list(list)
	if not members then
		members = {}
	end
	log("action","Unregistering mailing list `" .. list .. "`")
	mailing_list.lists[list] = nil
	save()
	return true
end

minetest.register_privilege("mailinglist", {
	description = S("Can manage mailing lists")
})

local cmd = chatcmdbuilder.register("mailinglist", {
    description = S("Manage mailing lists"),
    privs = {mailinglist = true}
})

cmd:sub("create :listname",function(name,listname)
	local status, errmsg = mailing_list.register_mailing_list(listname)
	if not status then
		return false, S("Mailing list register failed: @1", S(errmsg))
	end
	return true, S("Mailing list registered.")
end)

cmd:sub("add-member :listname :user:username",function(name,listname,user)
	local status, errmsg = mailing_list.add_mailing_list_member(listname,{user})
	if not status then
		return false, S("Adding mailing list member failed: @1", S(errmsg))
	end
	return true, S("Mailing list member added.")
end)

cmd:sub("remove-member :listname :user:username",function(name,listname,user)
	local status, errmsg = mailing_list.remove_mailing_list_member(listname,{user})
	if not status then
		return false, S("Removing mailing list member failed: @1", S(errmsg))
	end
	return true, S("Mailing list member removed.")
end)

cmd:sub("remove :listname",function(name,listname)
	local status, errmsg = mailing_list.unregister_mailing_list(listname)
	return true, S("Mailing list unregistered.")
end)

minetest.register_on_shutdown(save)

mail.register_on_send(function(recipients,m)
	for x,y in pairs(recipients) do
		print(string.sub(y,1,string.len(mailing_list.PREFIX)))
		if string.sub(y,1,string.len(mailing_list.PREFIX)) == mailing_list.PREFIX then
			log("PREFIX FOUND")
			recipients[x] = nil
			local list = string.sub(y,string.len(mailing_list.PREFIX) + 1)
			print(list)
			for x,y in pairs(mailing_list.lists[list] or {}) do
				if y then
					local msg = {
						unread  = true,
						sender  = m.from,
						to      = m.to,
						subject = "[List " .. list .. "] " .. m.subject,
						body    = m.body .. "\n\n--------------\nThis mail is delivered via the mailing list `" .. list .. "`.",
						time    = os.time(),
					}
					if m.cc then
						msg.cc  = m.cc
					end
					-- Calling the raw API
					local messages = mail.getMessages(x)
					table.insert(messages, 1, msg)
					mail.setMessages(x, messages)

					for _, player in ipairs(minetest.get_connected_players()) do
						local name = player:get_player_name()
						if name == x then
							if m.subject == "" then m.subject = "(No subject)" end
							if string.len(m.subject) > 30 then
								m.subject = string.sub(m.subject,1,27) .. "..."
							end
							minetest.chat_send_player(name,
									string.format(mail.receive_mail_message, m.from .. " in mailing list " .. list, m.subject))
						end
					end
				end
			end
		end
	end
end)


