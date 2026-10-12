# -*- coding: utf-8 -*-
# Lines the app itself says in Thai: Anorcha's reactions and hand-overs on a call,
# and how she opens and keeps a chat going when there is no assistant to write it.
# Keys are read by the app (see `Phrases` in ContentStore.swift).
# Pairs are (english, thai, romanisation); informal, between friends.

PHRASES = {
 # a short acknowledgement after an answer, on a call without the assistant
 "call.reactions": [
  ("I see.", "อ๋อ อย่างนี้นี่เอง", "ɔ̌ɔ, yàang-níi nîi-eeng"),
  ("Interesting!", "น่าสนใจนะ!", "nâa-sǒn-jai ná!"),
  ("Oh, really?", "จริงเหรอ?", "jing rə̌ə?"),
  ("Good, good.", "ดีแล้ว ดีแล้ว", "dii lɛ́ɛo, dii lɛ́ɛo"),
  ("Got it, thanks.", "เข้าใจแล้ว ขอบคุณนะ", "khâo-jai lɛ́ɛo, khɔ̀ɔp-khun ná"),
  ("That's nice.", "ดีจังเลย", "dii jang ləəi"),
 ],
 # said before a question that opens a new subject
 "call.bridges": [
  ("Listen, let me ask you something else.", "นี่ ขอถามอย่างอื่นหน่อยนะ", "nîi, khɔ̌ɔ thǎam yàang ʉ̀ʉn nɔ̀ɔi ná"),
  ("Now let's change the subject a little.", "ทีนี้ลองเปลี่ยนเรื่องคุยกันหน่อย", "thii-níi lɔɔng plìan rʉ̂ang khui kan nɔ̀ɔi"),
  ("Now tell me something else.", "ทีนี้เล่าเรื่องอื่นให้ฟังบ้างสิ", "thii-níi lâo rʉ̂ang ʉ̀ʉn hâi fang bâang sì"),
 ],
 # said before the first question after the greeting
 "call.leadIns": [
  ("So, tell me something.", "งั้นเล่าอะไรให้ฟังหน่อยสิ", "ngán lâo à-rai hâi fang nɔ̀ɔi sì"),
  ("Tell me a bit about it.", "เล่าเรื่องนี้ให้ฟังสักหน่อย", "lâo rʉ̂ang níi hâi fang sàk nɔ̀ɔi"),
 ],

 # the writing chat, offline: a follow-up that fits any message
 "chat.followUps": [
  ("Oh really? Why?", "จริงเหรอ? ทำไมล่ะ?", "jing rə̌ə? tham-mai lâ?"),
  ("Tell me more.", "เล่าให้ฟังอีกหน่อยสิ", "lâo hâi fang ìik nɔ̀ɔi sì"),
  ("And then what happened?", "แล้วเกิดอะไรขึ้นต่อ?", "lɛ́ɛo kə̀ət à-rai khʉ̂n tɔ̀ɔ?"),
  ("Who were you with?", "ตอนนั้นอยู่กับใคร?", "tɔɔn-nán yùu kàp khrai?"),
  ("What do you think?", "เธอคิดว่ายังไง?", "thəə khít wâa yang-ngai?"),
 ],
 "chat.goodbyes": [
  ("Nice to hear from you! Shall we write tomorrow?", "ดีใจที่ได้คุยกันนะ! พรุ่งนี้แชทกันอีกไหม?", "dii-jai thîi dâai khui kan ná! phrûng-níi chɛ́t kan ìik mǎi?"),
  ("OK, I have to go now. See you soon!", "โอเค ตอนนี้ต้องไปแล้ว ไว้เจอกันนะ!", "oo-khee, tɔɔn-níi tɔ̂ng pai lɛ́ɛo. wái jəə kan ná!"),
  ("Thanks for telling me. Talk later!", "ขอบคุณที่เล่าให้ฟังนะ ไว้คุยกันใหม่!", "khɔ̀ɔp-khun thîi lâo hâi fang ná. wái khui kan mài!"),
 ],

 # one opener and four follow-ups for each chat theme (ids as in WritingChapter.swift)
 "chat.opener.day": [("Hey! How did your day go?", "หวัดดี! วันนี้ทั้งวันเป็นยังไงบ้าง?", "wàt-dii! wan-níi tháng wan pen yang-ngai bâang?")],
 "chat.thread.day": [
  ("And how was the morning?", "แล้วตอนเช้าเป็นยังไง?", "lɛ́ɛo tɔɔn-cháo pen yang-ngai?"),
  ("Did you eat something good?", "ได้กินอะไรอร่อยไหม?", "dâai kin à-rai à-rɔ̀i mǎi?"),
  ("Who did you see today?", "วันนี้เจอใครบ้าง?", "wan-níi jəə khrai bâang?"),
  ("And what are you doing tomorrow?", "แล้วพรุ่งนี้จะทำอะไร?", "lɛ́ɛo phrûng-níi jà tham à-rai?"),
 ],
 "chat.opener.plan": [("Shall we meet this week? When are you free?", "อาทิตย์นี้เจอกันไหม? ว่างวันไหน?", "aa-thít níi jəə kan mǎi? wâang wan nǎi?")],
 "chat.thread.plan": [
  ("What time works for you?", "สะดวกกี่โมง?", "sà-dùak kìi moong?"),
  ("Where shall we meet?", "เจอกันที่ไหนดี?", "jəə kan thîi-nǎi dii?"),
  ("Who else shall we invite?", "ชวนใครไปด้วยอีกดี?", "chuan khrai pai dûai ìik dii?"),
  ("How are you getting there?", "จะไปที่นั่นยังไง?", "jà pai thîi-nân yang-ngai?"),
 ],
 "chat.opener.favour": [("Can I ask you a favor?", "ขอให้ช่วยอะไรหน่อยได้ไหม?", "khɔ̌ɔ hâi chûai à-rai nɔ̀ɔi dâai mǎi?")],
 "chat.thread.favour": [
  ("When would you need it?", "ต้องใช้เมื่อไหร่?", "tɔ̂ng chái mʉ̂a-rài?"),
  ("Has it happened before?", "เคยเป็นแบบนี้มาก่อนไหม?", "khəəi pen bɛ̀ɛp-níi maa kɔ̀ɔn mǎi?"),
  ("How can I help you?", "ให้ช่วยอะไรได้บ้าง?", "hâi chûai à-rai dâai bâang?"),
  ("Are you sure? Tell me everything.", "แน่ใจเหรอ? เล่าให้ฟังทั้งหมดเลย", "nɛ̂ɛ-jai rə̌ə? lâo hâi fang tháng-mòt ləəi"),
 ],
 "chat.opener.place": [("Where are you? Tell me what it's like there.", "อยู่ที่ไหนเนี่ย? เล่าหน่อยว่าที่นั่นเป็นยังไง", "yùu thîi-nǎi nîa? lâo nɔ̀ɔi wâa thîi-nân pen yang-ngai")],
 "chat.thread.place": [
  ("What's the weather like there?", "ที่นั่นอากาศเป็นยังไง?", "thîi-nân aa-kàat pen yang-ngai?"),
  ("What can you see from the window?", "มองออกไปนอกหน้าต่างเห็นอะไร?", "mɔɔng ɔ̀ɔk pai nɔ̂ɔk nâa-tàang hěn à-rai?"),
  ("Would you go back there?", "จะกลับไปที่นั่นอีกไหม?", "jà klàp pai thîi-nân ìik mǎi?"),
  ("Who did you go there with?", "ไปที่นั่นกับใคร?", "pai thîi-nân kàp khrai?"),
 ],
 "chat.opener.food": [("I'm hungry. What shall we eat tonight?", "หิวแล้ว คืนนี้กินอะไรดี?", "hǐu lɛ́ɛo. khʉʉn-níi kin à-rai dii?")],
 "chat.thread.food": [
  ("Are you cooking or shall we order?", "จะทำกินเองหรือสั่งดี?", "jà tham kin eeng rʉ̌ʉ sàng dii?"),
  ("What's in the fridge?", "ในตู้เย็นมีอะไรบ้าง?", "nai tûu-yen mii à-rai bâang?"),
  ("What's your favorite dish?", "อาหารจานโปรดของเธอคืออะไร?", "aa-hǎan jaan pròot khɔ̌ɔng thəə khʉʉ à-rai?"),
  ("What time shall we eat?", "จะกินกี่โมงดี?", "jà kin kìi moong dii?"),
 ],
 "chat.opener.news": [("Guess what happened to me today!", "ทายสิว่าวันนี้เราเจออะไรมา!", "thaai sì wâa wan-níi rao jəə à-rai maa!")],
 "chat.thread.news": [
  ("How did you react?", "แล้วเธอทำยังไงตอนนั้น?", "lɛ́ɛo thəə tham yang-ngai tɔɔn-nán?"),
  ("Did you tell anyone?", "บอกใครหรือยัง?", "bɔ̀ɔk khrai rʉ̌ʉ-yang?"),
  ("And what will you do now?", "แล้วตอนนี้จะทำยังไงต่อ?", "lɛ́ɛo tɔɔn-níi jà tham yang-ngai tɔ̀ɔ?"),
  ("Were you expecting it?", "คาดไว้ก่อนไหมว่าจะเป็นแบบนี้?", "khâat wái kɔ̀ɔn mǎi wâa jà pen bɛ̀ɛp-níi?"),
 ],
 "chat.opener.problem": [("I have a problem… what would you do?", "เรามีปัญหาอยู่เรื่องหนึ่ง… ถ้าเป็นเธอจะทำยังไง?", "rao mii pan-hǎa yùu rʉ̂ang nʉ̀ng… thâa pen thəə jà tham yang-ngai?")],
 "chat.thread.problem": [
  ("When did it start?", "เริ่มตั้งแต่เมื่อไหร่?", "rə̂əm tâng-tɛ̀ɛ mʉ̂a-rài?"),
  ("Have you already tried something?", "ลองทำอะไรไปแล้วหรือยัง?", "lɔɔng tham à-rai pai lɛ́ɛo rʉ̌ʉ-yang?"),
  ("Do you want me to help?", "อยากให้เราช่วยไหม?", "yàak hâi rao chûai mǎi?"),
  ("Whose fault is it, in your opinion?", "เธอว่าเป็นความผิดของใคร?", "thəə wâa pen khwaam-phìt khɔ̌ɔng khrai?"),
 ],
 "chat.opener.memory": [("Do you remember that time? I can't remember how it ended.", "จำครั้งนั้นได้ไหม? เรานึกไม่ออกว่ามันจบยังไง", "jam khráng nán dâai mǎi? rao nʉ́k mâi ɔ̀ɔk wâa man jòp yang-ngai")],
 "chat.thread.memory": [
  ("Who was with us?", "ตอนนั้นมีใครอยู่กับเราบ้าง?", "tɔɔn-nán mii khrai yùu kàp rao bâang?"),
  ("What season was it?", "ตอนนั้นเป็นฤดูอะไร?", "tɔɔn-nán pen rʉ́-duu à-rai?"),
  ("What do you remember best?", "เธอจำอะไรได้ชัดที่สุด?", "thəə jam à-rai dâai chát thîi-sùt?"),
  ("Would you do it again?", "จะทำแบบนั้นอีกไหม?", "jà tham bɛ̀ɛp-nán ìik mǎi?"),
 ],
}
