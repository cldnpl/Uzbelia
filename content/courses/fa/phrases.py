# -*- coding: utf-8 -*-
# Lines the app itself says in Persian: Anorcha's reactions and hand-overs on a call,
# and how she opens and keeps a chat going when there is no assistant to write it.
# Keys are read by the app (see `Phrases` in ContentStore.swift).
# Pairs are (english, persian, romanisation); she talks to a friend, so "to" (informal).

PHRASES = {
 # a short acknowledgement after an answer, on a call without the assistant
 "call.reactions": [
  ("I see.", "متوجه شدم.", "motavajjeh shodam."),
  ("Interesting!", "جالب است!", "jâleb ast!"),
  ("Oh, really?", "واقعاً؟", "vâghe'an?"),
  ("Good, good.", "خوب است، خوب است.", "khub ast, khub ast."),
  ("Got it, thanks.", "فهمیدم، ممنون.", "fahmidam, mamnun."),
  ("That's nice.", "چه خوب.", "che khub."),
 ],
 # said before a question that opens a new subject
 "call.bridges": [
  ("Listen, let me ask you something else.", "گوش کن، بگذار یک چیز دیگر از تو بپرسم.", "gush kon, bogzâr yek chiz-e digar az to beporsam."),
  ("Now let's change the subject a little.", "حالا بیا موضوع را کمی عوض کنیم.", "hâlâ biâ mowzu' râ kami avaz konim."),
  ("Now tell me something else.", "حالا یک چیز دیگر برایم بگو.", "hâlâ yek chiz-e digar barâyam begu."),
 ],
 # said before the first question after the greeting
 "call.leadIns": [
  ("So, tell me something.", "خب، یک چیزی برایم بگو.", "khob, yek chizi barâyam begu."),
  ("Tell me a bit about it.", "کمی درباره‌اش برایم تعریف کن.", "kami darbâre-ash barâyam ta'rif kon."),
 ],

 # the writing chat, offline: a follow-up that fits any message
 "chat.followUps": [
  ("Oh really? Why?", "واقعاً؟ چرا؟", "vâghe'an? cherâ?"),
  ("Tell me more.", "بیشتر برایم بگو.", "bishtar barâyam begu."),
  ("And then what happened?", "بعدش چه شد؟", "ba'dash che shod?"),
  ("Who were you with?", "با چه کسی بودی؟", "bâ che kasi budi?"),
  ("What do you think?", "تو چه فکر می‌کنی؟", "to che fekr mikoni?"),
 ],
 "chat.goodbyes": [
  ("Nice to hear from you! Shall we write tomorrow?", "خوشحالم که از تو خبر گرفتم! فردا هم برای هم بنویسیم؟", "khoshhâlam ke az to khabar gereftam! fardâ ham barâye ham benevisim?"),
  ("OK, I have to go now. See you soon!", "باشه، الان باید بروم. به‌زودی می‌بینمت!", "bâshe, alân bâyad beravam. be-zudi mibinamet!"),
  ("Thanks for telling me. Talk later!", "ممنون که برایم گفتی. بعداً حرف می‌زنیم!", "mamnun ke barâyam gofti. ba'dan harf mizanim!"),
 ],

 # one opener and four follow-ups for each chat theme (ids as in WritingChapter.swift)
 "chat.opener.day": [("Hey! How did your day go?", "سلام! امروز روزت چطور گذشت؟", "salâm! emruz ruzet chetor gozasht?")],
 "chat.thread.day": [
  ("And how was the morning?", "و صبح چطور گذشت؟", "va sobh chetor gozasht?"),
  ("Did you eat something good?", "چیز خوشمزه‌ای خوردی؟", "chiz-e khoshmaze-i khordi?"),
  ("Who did you see today?", "امروز چه کسی را دیدی؟", "emruz che kasi râ didi?"),
  ("And what are you doing tomorrow?", "و فردا چه کار می‌کنی؟", "va fardâ che kâr mikoni?"),
 ],
 "chat.opener.plan": [("Shall we meet this week? When are you free?", "این هفته همدیگر را ببینیم؟ کی وقتت آزاد است؟", "in hafte hamdigar râ bebinim? key vaghtet âzâd ast?")],
 "chat.thread.plan": [
  ("What time works for you?", "چه ساعتی برایت مناسب است؟", "che sâ'ati barâyat monâseb ast?"),
  ("Where shall we meet?", "کجا همدیگر را ببینیم؟", "kojâ hamdigar râ bebinim?"),
  ("Who else shall we invite?", "دیگر چه کسی را دعوت کنیم؟", "digar che kasi râ da'vat konim?"),
  ("How are you getting there?", "چطور به آنجا می‌روی؟", "chetor be ânjâ miravi?"),
 ],
 "chat.opener.favour": [("Can I ask you a favor?", "می‌توانم از تو خواهشی بکنم؟", "mitavânam az to khâheshi bokonam?")],
 "chat.thread.favour": [
  ("When would you need it?", "کی لازمش داری؟", "key lâzemash dâri?"),
  ("Has it happened before?", "قبلاً هم پیش آمده بود؟", "ghablan ham pish âmade bud?"),
  ("How can I help you?", "چطور می‌توانم کمکت کنم؟", "chetor mitavânam komaket konam?"),
  ("Are you sure? Tell me everything.", "مطمئنی؟ همه‌چیز را برایم تعریف کن.", "motma'enni? hame-chiz râ barâyam ta'rif kon."),
 ],
 "chat.opener.place": [("Where are you? Tell me what it's like there.", "کجایی؟ بگو آنجا چطور است.", "kojâyi? begu ânjâ chetor ast.")],
 "chat.thread.place": [
  ("What's the weather like there?", "هوای آنجا چطور است؟", "havâ-ye ânjâ chetor ast?"),
  ("What can you see from the window?", "از پنجره چه چیزی می‌بینی؟", "az panjare che chizi mibini?"),
  ("Would you go back there?", "دوباره آنجا می‌رفتی؟", "dobâre ânjâ mirafti?"),
  ("Who did you go there with?", "با چه کسی آنجا رفتی؟", "bâ che kasi ânjâ rafti?"),
 ],
 "chat.opener.food": [("I'm hungry. What shall we eat tonight?", "گرسنه‌ام. امشب چه بخوریم؟", "gorosne-am. emshab che bokhorim?")],
 "chat.thread.food": [
  ("Are you cooking or shall we order?", "خودت آشپزی می‌کنی یا سفارش بدهیم؟", "khodet âshpazi mikoni yâ sefâresh bedahim?"),
  ("What's in the fridge?", "در یخچال چه هست؟", "dar yakhchâl che hast?"),
  ("What's your favorite dish?", "غذای مورد علاقه‌ات چیست؟", "ghazâ-ye mored-e alâghe-at chist?"),
  ("What time shall we eat?", "ساعت چند غذا بخوریم؟", "sâ'at chand ghazâ bokhorim?"),
 ],
 "chat.opener.news": [("Guess what happened to me today!", "حدس بزن امروز چه اتفاقی برایم افتاد!", "hads bezan emruz che ettefâghi barâyam oftâd!")],
 "chat.thread.news": [
  ("How did you react?", "چه واکنشی نشان دادی؟", "che vâkoneshi neshân dâdi?"),
  ("Did you tell anyone?", "به کسی گفتی؟", "be kasi gofti?"),
  ("And what will you do now?", "و حالا چه کار می‌کنی؟", "va hâlâ che kâr mikoni?"),
  ("Were you expecting it?", "انتظارش را داشتی؟", "entezârash râ dâshti?"),
 ],
 "chat.opener.problem": [("I have a problem… what would you do?", "یک مشکلی دارم… تو جای من بودی چه کار می‌کردی؟", "yek moshkeli dâram… to jâ-ye man budi che kâr mikardi?")],
 "chat.thread.problem": [
  ("When did it start?", "از کی شروع شد؟", "az key shoru' shod?"),
  ("Have you already tried something?", "تا حالا چیزی را امتحان کرده‌ای؟", "tâ hâlâ chizi râ emtehân karde-i?"),
  ("Do you want me to help?", "می‌خواهی کمکت کنم؟", "mikhâhi komaket konam?"),
  ("Whose fault is it, in your opinion?", "به نظرت تقصیر کیست؟", "be nazaret taghsir-e kist?"),
 ],
 "chat.opener.memory": [("Do you remember that time? I can't remember how it ended.", "آن دفعه یادت هست؟ یادم نمی‌آید آخرش چه شد.", "ân daf'e yâdet hast? yâdam nemiâyad âkharash che shod.")],
 "chat.thread.memory": [
  ("Who was with us?", "چه کسی با ما بود؟", "che kasi bâ mâ bud?"),
  ("What season was it?", "چه فصلی بود؟", "che fasli bud?"),
  ("What do you remember best?", "چه چیزی را از همه بهتر یادت هست؟", "che chizi râ az hame behtar yâdet hast?"),
  ("Would you do it again?", "دوباره این کار را می‌کردی؟", "dobâre in kâr râ mikardi?"),
 ],
}
