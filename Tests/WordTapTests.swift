import XCTest
@testable import Uzbelia

/// A tap on one word explains that word — or the set expression it belongs to — and
/// never the sentence around it.
final class WordTapTests: XCTestCase {

    private let vocabulary = [
        Pair(it: "buongiorno", uz: "xayrli tong"),
        Pair(it: "mattino", uz: "tong"),
        Pair(it: "libro", uz: "kitob"),
        Pair(it: "andare", uz: "bormoq"),
        Pair(it: "c'è", uz: "bor"),
        Pair(it: "parlare", uz: "gapirmoq"),
        Pair(it: "casa", uz: "uy"),
        Pair(it: "acqua", uz: "suv"),
    ]
    private let sentences = [
        Pair(it: "Buongiorno, Malika!", uz: "Xayrli tong, Malika!"),
        Pair(it: "Il mio libro è a casa.", uz: "Mening kitobim uyda."),
    ]

    override func setUp() {
        super.setUp()
        Glossary.prime(with: vocabulary + sentences, vocabulary: vocabulary)
    }

    private func words(_ line: String) -> [String] {
        line.split(separator: " ").map(String.init)
    }

    func testAWordInsideASetExpressionExplainsTheExpression() {
        let line = words("Xayrli tong, Malika!")
        let hit = Glossary.expression(in: line, containing: 1, from: .uz)
        XCTAssertEqual(hit?.span, 0...1)
        XCTAssertEqual(hit?.meaning, "buongiorno")
        XCTAssertNil(Glossary.expression(in: line, containing: 2, from: .uz),
                     "the name is not part of the greeting")
    }

    func testTheSentenceItselfIsNeverTheExpression() {
        // the course knows this sentence and its translation, but a tap on one of its
        // words must not answer with the whole of it
        let line = words("Mening kitobim uyda.")
        for i in line.indices {
            XCTAssertNil(Glossary.expression(in: line, containing: i, from: .uz))
        }
    }

    func testASingleWordIsLookedUpOnItsOwn() {
        XCTAssertEqual(Glossary.word("tong,", from: .uz), "mattino")
        XCTAssertEqual(Glossary.word("Kitob.", from: .uz), "libro")
        XCTAssertNil(Glossary.word("kitobim", from: .uz), "an inflected form is not a listed word")
    }

    func testAnInflectedUzbekWordIsReadBackToItsDictionaryForm() {
        XCTAssertEqual(Glossary.base(of: "kitobim", from: .uz)?.base, "kitob")
        XCTAssertEqual(Glossary.base(of: "kitoblarimiz", from: .uz)?.meaning, "libro")
        XCTAssertEqual(Glossary.base(of: "uyda", from: .uz)?.meaning, "casa")
        XCTAssertNil(Glossary.base(of: "uya", from: .uz), "a short root needs a real ending")
        let went = Glossary.base(of: "bordim", from: .uz)
        XCTAssertEqual(went?.base, "bormoq", "a verb ending reads the root as a verb")
        XCTAssertEqual(went?.meaning, "andare")
        XCTAssertEqual(Glossary.base(of: "gapiryapman", from: .uz)?.base, "gapirmoq")
        XCTAssertNil(Glossary.base(of: "kitobxyz", from: .uz), "an unknown tail is not an ending")
    }

    func testAnInflectedItalianWordIsReadBackToo() {
        Glossary.prime(with: [Pair(it: "parlare", uz: "gapirmoq"), Pair(it: "acqua", uz: "suv"),
                              Pair(it: "libro", uz: "kitob")], vocabulary: [])
        XCTAssertEqual(Glossary.base(of: "parliamo", from: .it)?.base, "parlare")
        XCTAssertEqual(Glossary.base(of: "parlo", from: .it)?.meaning, "gapirmoq")
        XCTAssertEqual(Glossary.base(of: "l'acqua", from: .it)?.base, "acqua")
        XCTAssertEqual(Glossary.base(of: "libri", from: .it)?.base, "libro")
    }

    func testTheRealCourseHasExpressionsToExplain() {
        let curriculum = ContentStore.loadCurriculum()
        Glossary.prime(with: curriculum.allPairs + curriculum.allDrills,
                       vocabulary: curriculum.allLessons.flatMap(\.vocab))
        let multiWord = curriculum.allLessons.flatMap(\.vocab).first { $0.wordCount(.uz) == 2 }
        guard let multiWord else { return XCTFail("the course teaches no two-word expressions") }
        let line = words(multiWord.uz + " va boshqalar")
        XCTAssertEqual(Glossary.expression(in: line, containing: 0, from: .uz)?.span, 0...1)
    }
}
