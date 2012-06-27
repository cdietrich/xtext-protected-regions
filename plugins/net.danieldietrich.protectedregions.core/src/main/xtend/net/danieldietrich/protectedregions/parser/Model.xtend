package net.danieldietrich.protectedregions.parser

import static net.danieldietrich.protectedregions.parser.Match.*
import static net.danieldietrich.protectedregions.util.Strings.*

import java.util.List
import java.util.regex.Pattern;

/** A model is built by blocks with start/end Element and children between. */
class Model {

	@Property var Model root = this
	@Property val List<Model> children = newArrayList()
	@Property val Symbol symbol
	@Property val Element start
	@Property val Element end

	new(Symbol symbol, Element start, Element end) {
		this._symbol = symbol
		this._start = start
		this._end = end
	}

	def add(Model child) {
		if (child == root && child != this) {
			children.addAll(root.children)
		} else {
			children.add(child)
			child.root = root
		}
		child
	}
	
	override toString() { toString(0) }
	
	def private String toString(int depth) {
		val indent = indent(depth)
    	indent + symbol.name +"("+ start +", "+ end +")"+
    		if (children.size == 0) ""
    		else "(\n"+ children.map[toString(depth+1)].reduce(l,r | l +",\n"+ r) +"\n"+ indent +")"
	}
	
}

@Data class Symbol {
	val String name
}

class ElementExtensions {
	
	// TODO: move this away
	public val EOL = SomeElement(StrElement("\r\n"), StrElement("\n"), StrElement("\r"))
	
	def StrElement(String s) {
		new StrElement(s)
	}
	
	def GreedyElement(String s) {
		new GreedyElement(s)
	}
	
	def RegExElement(String regEx) {
		new RegExElement(regEx)
	}
	
	def Element SomeElement(Element... elements) {
  		new SomeElement(elements)
  	}
  	
  	def Element NoElement() {
		new NoElement()
	}
	
	def Element SeqElement(Element... sequence) {
		new SeqElement(sequence)
	}
	
}

/** Element which can be located within a String. */
abstract class Element {
	
	/** Returns an implementation specific Match of this Element, maybe NOT_FOUND. */
	def Match indexOf(String source, int index)
	
	/**
	 * Checks if this.indexOf(input, index) < that.indexOf(input, index).
	 * Also true if that not found or indexes are equal and that.length < this.length.
	 */
	def ahead(Element that, String input, int index) {
		val m1 = this.indexOf(input, index)
		val m2 = that.indexOf(input, index)
		!m2.found || (m1.found && (m1.index < m2.index || (m1.index == m2.index && m1.length >= m2.length)))
	}
	
}

/** A plain String representation. */
class StrElement extends Element {
	
	val String s

	new(String s) {
		if (s.isNullOrEmpty) throw new IllegalArgumentException("StrElement argument cannot be empty")
		this.s = s
	}

	/** Returns the first Match of this String or NOT_FOUND. */	
	override indexOf(String source, int index) {
		val int i = source.indexOf(s, index)
		if (i == -1) NOT_FOUND else new Match(i, s.length)
	}
	
	override String toString() {
		"StrElement("+ s.replaceAll("\\r", "\n").replaceAll("\\n+", "<EOL>").replaceAll("\\s+", " ") +")"
	}
	
}

/** A greedy String representation. */
class GreedyElement extends Element {

	val String s

	new(String s) {
		if (s.isNullOrEmpty) throw new IllegalArgumentException("GreedyElement argument cannot be empty")
		s.toCharArray.reduce[x,y | if (x == y) x else throw new IllegalArgumentException("All characters have to be equal")]
		this.s = s
	}
	
	/**
	 * Returns the first greedy Match of this String or NOT_FOUND.
	 * Example: new GreedyElement("'''").indexOf("Test''''123", 0) returns Match(5, 3) remaining "123"
	 */
	override indexOf(String source, int index) {
		var int i = source.indexOf(s, index)
		while (source.indexOf(s, i+1) == i+1) i = i + 1
		if (i == -1) NOT_FOUND else new Match(i, s.length)
	}

	override String toString() {
		"GreedyElement("+ s.replaceAll("\\r", "\n").replaceAll("\\n+", "<EOL>").replaceAll("\\s+", " ") +")"
	}
	
}

/** An reqular expression element. */
class RegExElement extends Element {
	
	val Pattern pattern
	
	new(String regEx) {
		if (regEx.isNullOrEmpty) throw new IllegalArgumentException("RegExElement argument cannot be empty")
		pattern = Pattern::compile(regEx)
	}
	
	/** Returns the first Match of this Pattern or NOT_FOUND. */
	override indexOf(String source, int index) {
		val m = pattern.matcher(source)
		val found = m.find(index)
		if (found) new Match(m.start, m.end - m.start) else NOT_FOUND
	}
	
	override String toString() {
		"RegExElement("+ pattern.pattern() + ")"
	}
	
}

/** A list of possibilities. */
class SomeElement extends Element {
	
	val Element[] elements
	
	new(Element... elements) {
		if (elements.size == 0) throw new IllegalArgumentException("SomeElement argument needs at least one Element")
		this.elements = elements
	}
	
	/** Returns the Match of the Element occurring first or NOT_FOUND. */
	override indexOf(String source, int index) {
		val e = elements.reduce(e1, e2 | if (e1.ahead(e2, source, index)) e1 else e2)
		if (e == null) NOT_FOUND else e.indexOf(source, index)
	}
	
	override String toString() {
		"SomeElement("+ elements.map[toString].reduce(s1, s2 | s1 +", "+ s2) +")"
	}
	
}

/** Placeholder for no Element. */
class NoElement extends Element {
	
	/** Throws UnsupportedOperationException. */
	override indexOf(String source, int index) {
		throw new UnsupportedOperationException()
	}
	
	override String toString() {
		"NoElement"
	}
	
}

/** A sequence of Elements. */
class SeqElement extends Element {
	
	val Element[] sequence
	
	new(Element... sequence) {
		if (sequence.size == 0) throw new IllegalArgumentException("SeqElement argument needs at least one Element")
		this.sequence = sequence
	}
	
	/** Matches the concatenation of this sequence or NOT_FOUND. */
	override indexOf(String source, int index) {
		sequence.map[indexOf(source, index)].reduce(m1, m2 |
			if (m1 == NOT_FOUND || m2 == NOT_FOUND || m2.index != m1.index + m1.length)
				NOT_FOUND
			else
				new Match(m1.index, m1.length + m2.length)
		)
	}
	
	override String toString() {
		"SeqElement("+ sequence.map[toString].reduce(s1, s2 | s1 +", "+ s2) +")"
	}
	
}

/** A location (index, length) of a string match. */
@Data class Match {
	
	public static val NOT_FOUND = new Match(-1, -1)
	
	val int index
	val int length
	
	def boolean found() { index > -1 }
	def int end() { index + length }
	
}
