# -*- coding: utf-8 -*-
# Lines the app itself says in Uzbek: Anorcha's reactions and hand-overs on a call,
# and how she opens and keeps a chat going when there is no assistant to write it.
# Keys are read by the app (see `Phrases` in ContentStore.swift).

PHRASES = {
 # a short acknowledgement after an answer, on a call without the assistant
 "call.reactions": [
  ("I see.", "Tushunarli."),
  ("Interesting!", "Qiziq!"),
  ("Oh, really?", "Rostdanmi?"),
  ("Good, good.", "Yaxshi, yaxshi."),
  ("Got it, thanks.", "Tushundim, rahmat."),
  ("That's nice.", "Zo'r ekan."),
 ],
 # said before a question that opens a new subject
 "call.bridges": [
  ("Listen, let me ask you something else.", "Eshit, yana bir narsani so'rayman."),
  ("Now let's change the subject a little.", "Endi mavzuni biroz o'zgartiramiz."),
  ("Now tell me something else.", "Endi menga boshqa bir narsani aytib ber."),
 ],
 # said before the first question after the greeting
 "call.leadIns": [
  ("So, tell me something.", "Xo'sh, menga bir narsani ayt."),
  ("Tell me a bit about it.", "Ayt-chi, biroz gapirib ber."),
 ],

 # the writing chat, offline: a follow-up that fits any message
 "chat.followUps": [
  ("Oh really? Why?", "Rostdanmi? Nega?"),
  ("Tell me more.", "Ko'proq aytib ber."),
  ("And then what happened?", "Keyin nima bo'ldi?"),
  ("Who were you with?", "Kim bilan eding?"),
  ("What do you think?", "Sen nima deb o'ylaysan?"),
 ],
 "chat.goodbyes": [
  ("Nice to hear from you! Shall we write tomorrow?", "Gaplashganimiz yaxshi bo'ldi! Ertaga yozishamizmi?"),
  ("OK, I have to go now. See you soon!", "Mayli, endi ketishim kerak. Ko'rishguncha!"),
  ("Thanks for telling me. Talk later!", "Aytib berganing uchun rahmat. Keyinroq gaplashamiz!"),
 ],

 # one opener and four follow-ups for each chat theme (ids as in WritingChapter.swift)
 "chat.opener.day": [("Hey! How did your day go?", "Salom! Bugun kuning qanday o'tdi?")],
 "chat.thread.day": [
  ("And how was the morning?", "Ertalab qanday o'tdi?"),
  ("Did you eat something good?", "Mazali biror narsa yedingmi?"),
  ("Who did you see today?", "Bugun kimni ko'rding?"),
  ("And what are you doing tomorrow?", "Ertaga nima qilasan?"),
 ],
 "chat.opener.plan": [("Shall we meet this week? When are you free?", "Shu hafta ko'rishamizmi? Qachon bo'sh bo'lasan?")],
 "chat.thread.plan": [
  ("What time works for you?", "Soat nechada qulay?"),
  ("Where shall we meet?", "Qayerda uchrashamiz?"),
  ("Who else shall we invite?", "Yana kimni taklif qilamiz?"),
  ("How are you getting there?", "U yerga qanday borasan?"),
 ],
 "chat.opener.favour": [("Can I ask you a favor?", "Sendan bir narsa so'rasam maylimi?")],
 "chat.thread.favour": [
  ("When would you need it?", "Qachon kerak bo'ladi?"),
  ("Has it happened before?", "Avval ham shunday bo'lganmi?"),
  ("How can I help you?", "Qanday yordam bera olaman?"),
  ("Are you sure? Tell me everything.", "Ishonching komilmi? Hammasini aytib ber."),
 ],
 "chat.opener.place": [("Where are you? Tell me what it's like there.", "Qayerdasan? U yer qanaqa, aytib ber.")],
 "chat.thread.place": [
  ("What's the weather like there?", "U yerda ob-havo qanday?"),
  ("What can you see from the window?", "Derazadan nima ko'rinadi?"),
  ("Would you go back there?", "Yana borarmiding?"),
  ("Who did you go there with?", "U yerga kim bilan bording?"),
 ],
 "chat.opener.food": [("I'm hungry. What shall we eat tonight?", "Qornim ochdi. Kechqurun nima yeymiz?")],
 "chat.thread.food": [
  ("Are you cooking or shall we order?", "O'zing pishirasanmi yoki buyurtma qilamizmi?"),
  ("What's in the fridge?", "Muzlatgichda nima bor?"),
  ("What's your favorite dish?", "Eng yoqtirgan taoming qaysi?"),
  ("What time shall we eat?", "Soat nechada ovqatlanamiz?"),
 ],
 "chat.opener.news": [("Guess what happened to me today!", "Bugun menga nima bo'ldi, top-chi!")],
 "chat.thread.news": [
  ("How did you react?", "Qanday munosabat bildirding?"),
  ("Did you tell anyone?", "Birovga aytdingmi?"),
  ("And what will you do now?", "Endi nima qilasan?"),
  ("Were you expecting it?", "Buni kutgandingmi?"),
 ],
 "chat.opener.problem": [("I have a problem… what would you do?", "Bir muammom bor… sen bo'lsang nima qilarding?")],
 "chat.thread.problem": [
  ("When did it start?", "Qachon boshlandi?"),
  ("Have you already tried something?", "Biror narsa qilib ko'rdingmi?"),
  ("Do you want me to help?", "Yordam berishimni xohlaysanmi?"),
  ("Whose fault is it, in your opinion?", "Sencha kim aybdor?"),
 ],
 "chat.opener.memory": [("Do you remember that time? I can't remember how it ended.", "O'sha safar esingdami? Qanday tugaganini eslay olmayapman.")],
 "chat.thread.memory": [
  ("Who was with us?", "Biz bilan kim bor edi?"),
  ("What season was it?", "Qaysi faslda edi?"),
  ("What do you remember best?", "Eng yaxshi nimani eslaysan?"),
  ("Would you do it again?", "Yana shunday qilarmiding?"),
 ],
}
