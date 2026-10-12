# -*- coding: utf-8 -*-
# Lines the app itself says in Tagalog: Anorcha's reactions and hand-overs on a call,
# and how she opens and keeps a chat going when there is no assistant to write it.
# Keys are read by the app (see `Phrases` in ContentStore.swift).

PHRASES = {
 # a short acknowledgement after an answer, on a call without the assistant
 "call.reactions": [
  ("I see.", "Ah, ganoon pala."),
  ("Interesting!", "Ang interesante!"),
  ("Oh, really?", "Ay, talaga?"),
  ("Good, good.", "Mabuti, mabuti."),
  ("Got it, thanks.", "Naintindihan ko, salamat."),
  ("That's nice.", "Ang ganda naman."),
 ],
 # said before a question that opens a new subject
 "call.bridges": [
  ("Listen, let me ask you something else.", "Makinig ka, may iba pa akong itatanong sa iyo."),
  ("Now let's change the subject a little.", "Ngayon, ibahin natin nang kaunti ang usapan."),
  ("Now tell me something else.", "Ngayon, magkuwento ka naman ng ibang bagay."),
 ],
 # said before the first question after the greeting
 "call.leadIns": [
  ("So, tell me something.", "O sige, may ikuwento ka sa akin."),
  ("Tell me a bit about it.", "Ikuwento mo naman nang kaunti."),
 ],

 # the writing chat, offline: a follow-up that fits any message
 "chat.followUps": [
  ("Oh really? Why?", "Talaga? Bakit?"),
  ("Tell me more.", "Magkuwento ka pa."),
  ("And then what happened?", "Tapos, ano ang nangyari?"),
  ("Who were you with?", "Sino ang kasama mo?"),
  ("What do you think?", "Ano sa tingin mo?"),
 ],
 "chat.goodbyes": [
  ("Nice to hear from you! Shall we write tomorrow?", "Natutuwa akong makabalita sa iyo! Magsulatan ulit tayo bukas?"),
  ("OK, I have to go now. See you soon!", "Sige, kailangan ko nang umalis. Kita-kits!"),
  ("Thanks for telling me. Talk later!", "Salamat sa pagkukuwento mo. Usap tayo mamaya!"),
 ],

 # one opener and four follow-ups for each chat theme (ids as in WritingChapter.swift)
 "chat.opener.day": [("Hey! How did your day go?", "Uy! Kumusta ang araw mo?")],
 "chat.thread.day": [
  ("And how was the morning?", "E kumusta naman ang umaga mo?"),
  ("Did you eat something good?", "May kinain ka bang masarap?"),
  ("Who did you see today?", "Sino ang nakita mo ngayong araw?"),
  ("And what are you doing tomorrow?", "E ano ang gagawin mo bukas?"),
 ],
 "chat.opener.plan": [("Shall we meet this week? When are you free?", "Magkita kaya tayo ngayong linggo? Kailan ka libre?")],
 "chat.thread.plan": [
  ("What time works for you?", "Anong oras ang ayos sa iyo?"),
  ("Where shall we meet?", "Saan tayo magkikita?"),
  ("Who else shall we invite?", "Sino pa ang iimbitahin natin?"),
  ("How are you getting there?", "Paano ka pupunta roon?"),
 ],
 "chat.opener.favour": [("Can I ask you a favor?", "Puwede ba akong humingi ng pabor sa iyo?")],
 "chat.thread.favour": [
  ("When would you need it?", "Kailan mo ito kakailanganin?"),
  ("Has it happened before?", "Nangyari na ba ito dati?"),
  ("How can I help you?", "Paano kita matutulungan?"),
  ("Are you sure? Tell me everything.", "Sigurado ka ba? Ikuwento mo sa akin ang lahat."),
 ],
 "chat.opener.place": [("Where are you? Tell me what it's like there.", "Nasaan ka? Ikuwento mo kung ano ang itsura diyan.")],
 "chat.thread.place": [
  ("What's the weather like there?", "Kumusta ang panahon diyan?"),
  ("What can you see from the window?", "Ano ang nakikita mo mula sa bintana?"),
  ("Would you go back there?", "Babalik ka pa ba roon?"),
  ("Who did you go there with?", "Sino ang kasama mo nang pumunta ka roon?"),
 ],
 "chat.opener.food": [("I'm hungry. What shall we eat tonight?", "Gutom na ako. Ano ang kakainin natin mamayang gabi?")],
 "chat.thread.food": [
  ("Are you cooking or shall we order?", "Ikaw ba ang magluluto, o oorder na lang tayo?"),
  ("What's in the fridge?", "Ano ang laman ng ref?"),
  ("What's your favorite dish?", "Ano ang paborito mong ulam?"),
  ("What time shall we eat?", "Anong oras tayo kakain?"),
 ],
 "chat.opener.news": [("Guess what happened to me today!", "Hulaan mo kung ano ang nangyari sa akin ngayong araw!")],
 "chat.thread.news": [
  ("How did you react?", "Ano ang naging reaksiyon mo?"),
  ("Did you tell anyone?", "May pinagsabihan ka ba?"),
  ("And what will you do now?", "E ano ang gagawin mo ngayon?"),
  ("Were you expecting it?", "Inaasahan mo ba iyon?"),
 ],
 "chat.opener.problem": [("I have a problem… what would you do?", "May problema ako… ano ang gagawin mo kung ikaw ako?")],
 "chat.thread.problem": [
  ("When did it start?", "Kailan ito nagsimula?"),
  ("Have you already tried something?", "May sinubukan ka na bang gawin?"),
  ("Do you want me to help?", "Gusto mo bang tulungan kita?"),
  ("Whose fault is it, in your opinion?", "Sa tingin mo, kaninong kasalanan ito?"),
 ],
 "chat.opener.memory": [("Do you remember that time? I can't remember how it ended.", "Naaalala mo ba noong araw na iyon? Hindi ko na maalala kung paano iyon natapos.")],
 "chat.thread.memory": [
  ("Who was with us?", "Sino ang kasama natin noon?"),
  ("What season was it?", "Anong panahon ng taon iyon?"),
  ("What do you remember best?", "Ano ang pinakanaaalala mo?"),
  ("Would you do it again?", "Gagawin mo ba ulit iyon?"),
 ],
}
